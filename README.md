# TripFund — ДЗ №2 «Сбор на поездку команды»

Домашнее задание по Solidity. Подготовлена реализация базовых требований **TripFund** (до 10 баллов) и бонуса **V2 / Transparent Proxy / проверка совместимости OpenZeppelin Upgrades** (до 3 дополнительных баллов). Итоговая оценка зависит от успешного запуска тестов и проверки преподавателем.

> **Проверено локально 16.10.2026:** `bash scripts/setup.sh` завершён с кодом 0. `forge build --force` — успешно; `forge test --force -vv` — **30 passed, 0 failed, 0 skipped**, fuzz: 256 прогонов; `npm run validate:upgrade` — **SUCCESS**, совместимость `TripFund → TripFundV2` подтверждена. Проверены пункты 1–12 исходного PDF. Подробности, версии и ограничения — в `REVIEW_REPORT.md`. GitHub Actions ещё не запускался: проект не опубликован.

## 1. Требования и версии

- Foundry **v1.8.5** (`forge`, `cast`, при необходимости `anvil`); эта же версия закреплена в CI.
- Solidity **0.8.27**, EVM **Cancun**.
- Node.js **20+** и npm (для OpenZeppelin Upgrades CLI). Локальная проверка: Node.js **v25.8.1**, npm **11.11.0**; CI использует Node.js 22.
- OpenZeppelin Contracts + Contracts Upgradeable **5.7.0**.
- OpenZeppelin Foundry Upgrades **v0.4.2**.
- OpenZeppelin Upgrades Core CLI **1.46.0** (`package.json`).
- forge-std **v1.16.2**.

Solidity-зависимости закреплены Git-сабмодулями, npm-зависимости — `package-lock.json`; установка описана ниже. Для Unix/WSL/macOS используется Bash; на Windows удобнее WSL или Git Bash.

## 2. Подготовка проекта и проверка перед сдачей

Понадобится интернет для **первой** загрузки зависимостей. В архиве намеренно нет многомегабайтных копий `forge-std` и OpenZeppelin: скрипт установит **фиксированные версии**, а GitHub Action автоматически проверит проект при публикации.

1. Установите Foundry (`forge`), Git и Node.js 20+ (с npm).
2. Откройте терминал **в корне проекта**.
3. Выполните **одну команду**:

```bash
bash scripts/setup.sh
```

Скрипт работает как после извлечения ZIP (создаёт локальный Git-репозиторий), так и после клонирования репозитория. Он устанавливает `forge-std@v1.16.2`, `openzeppelin-contracts-upgradeable@v5.7.0` и `openzeppelin-foundry-upgrades@v0.4.2`, включая вложенный `openzeppelin-contracts`. Затем устанавливает npm-пакеты через `npm ci` при наличии `package-lock.json` (иначе `npm install`) и запускает **все три проверки**:

```bash
forge build --force
forge test --force -vv
npm run validate:upgrade
```

Для повторного запуска без переустановки зависимостей:

```bash
bash scripts/check.sh
```

OpenZeppelin Foundry Upgrades действительно проверяет безопасность реализации и V1 → V2 storage layout: в конфигурации включены `ffi`, `ast`, `build_info`, `storageLayout`, а в V2 указана `@custom:oz-upgrades-from TripFund`. Проверка **не** выключена, `unsafeSkipAllChecks` не применяется. `--force` обновляет build info для CLI при каждом запуске тестов.

**Локальные проверки уже пройдены.** После публикации проверьте зелёный статус **Solidity checks (base + proxy V2 bonus)** в разделе Actions на GitHub. Скрипт ничего не публикует самостоятельно.

## 3. Структура

```text
.
├── src/
│   ├── TripFund.sol             # V1: взносы, вывод, возвраты
│   ├── TripFundV2.sol           # V2: взнос за другого участника
│   └── MockToken.sol            # Учебный OpenZeppelin ERC20 (без fee/rebasing)
├── test/
│   ├── TripFund.t.sol           # Проверки базового задания
│   └── TripFundUpgrade.t.sol    # Бонус: прокси и совместимость V1->V2
├── scripts/
│   ├── setup.sh                 # Установка зависимостей и проверки
│   └── check.sh                 # Проверки без переустановки
├── foundry.toml
├── remappings.txt
├── package.json
├── package-lock.json            # Зафиксированные npm-зависимости
├── .gitmodules                  # Solidity-зависимости; SHA закреплены в Git
├── .github/workflows/solidity.yml # Автоматическая проверка GitHub Actions
├── REVIEW_REPORT.md            # Сверка с требованиями и риски
└── README.md
```

## 4. Как работает V1

Создаём **TransparentUpgradeableProxy (OpenZeppelin 5.x)** с реализацией `TripFund` и одним вызовом `initialize(token, organizer, goal, deadline)` в конструкторе прокси. `goal` и `amount` указываются **в минимальных единицах ERC-20**, `deadline` — Unix-секунды. Запрещаются нулевые адреса, нулевая цель, не-будущий дедлайн. В рабочем контракте нет публичных функций изменения этих параметров.

- `contribute(amount)` до дедлайна: `amount > 0`, плательщик — `msg.sender`, заранее требуется `approve` у ERC-20 с **адресом прокси** в качестве spender. Используется `SafeERC20.safeTransferFrom`.
- `contributions(address)` показывает вклад, `totalRaised` — **историческую сумму всех принятых взносов**. После возвратов и вывода она **не уменьшается**.
- При `timestamp >= deadline` и `totalRaised >= goal` `withdraw()` может однократно вызвать только `organizer`. Организатор получает **ровно `totalRaised`**.
- При `timestamp >= deadline` и `totalRaised < goal` каждый участник вызывает `refund()` сам. Возвращается **весь его записанный вклад**, затем он обнуляется; повторный возврат невозможен.
- Прямой `ERC20.transfer(proxy, x)` не создаёт вклад и не меняет `totalRaised`. Эти токены **остаются в контракте** после обычных выплат или возвратов.
- Применяются custom errors, reentrancy guard, SafeERC20 и порядок checks / effects / interactions. В тестовом ERC-20 нет комиссии при переводе и rebasing.

### Пример `approve` + `contribute`

```solidity
IERC20 token = IERC20(tokenAddress);
TripFund trip = TripFund(proxyAddress);

// Вызовы инициирует один и тот же адрес участника:
token.approve(proxyAddress, 250);  // 250 минимальных единиц токена
trip.contribute(250);

// После взноса:
// trip.contributions(msg.sender) == 250
// trip.totalRaised() увеличилось на 250
```

Важно: `approve` для **адреса реализации** (`implementation`) не даёт прокси права списать средства. При использовании Foundry это показано в `_contribute` / `_pay` тестов.

## 5. Бонус: V2 / Transparent Proxy / Upgrades

- `TripFund` содержит защищённый инициализатор. В его конструкторе вызывается `_disableInitializers()`, блокируя прямую инициализацию реализации.
- В тестах V1 разворачивается за `TransparentUpgradeableProxy` с выделенным владельцем `ProxyAdmin`. Инициализация передаётся при развёртывании (без незаполненного промежутка).
- `TripFundV2` наследуется от V1 и **не добавляет переменных хранилища**. Метка `@custom:oz-upgrades-from TripFund` позволяет OpenZeppelin проверять совместимость.
- `contributeFor(beneficiary, amount)`: ERC-20 списываются у `msg.sender`; `beneficiary` получает учтённый вклад и право `refund`. Нулевой адрес и нулевая сумма запрещены. Выпускается событие `ContributedFor(payer, beneficiary, amount)`.
- `TripFundUpgrade.t.sol` разворачивает **валидируемый прокси**, обновляет через `Upgrades.upgradeProxy`, сохраняет адрес и состояние; проверяет отказ постороннему владельцу `ProxyAdmin` в обновлении и невозможность повторной инициализации.
- Реальный `upgradeProxy` вызывается **до дедлайна**, затем проверяются вклад V1, дополнительный `contributeFor` и обычный `contribute`, а после неудачного сбора — независимые возвраты старым вкладчикам и бенефициару.

Учтите: владелец `ProxyAdmin` и `organizer` — **две разные роли**. Владение токенами тоже не даёт права обновлять реализацию.

## 6. Тестовые сценарии

**База:**

- Начальные настройки, нулевые адреса/цель и не-будущий срок, блокировка повторного `initialize`.
- Два участника, повторные взносы и fuzz-тест накопления.
- Нулевой взнос, недостаточный allowance (в том числе нулевой), недостаточный баланс — откат без изменения учёта и токенных балансов.
- Дедлайн минус 1 секунда и ровно дедлайн; отсутствие досрочных `withdraw` и `refund` даже при выполненной цели.
- Сумма ровно цели / выше цели; запрет чужого и повторного вывода, а также возврата при успехе.
- Неудачная кампания: независимые полные возвраты, запрет возврата без вклада, повторного возврата и вывода при провале.
- Прямой перевод токенов до завершения — токены остаются после выплат при успехе **и** при неудаче.

**Бонус:**

- V1 -> V2: сохранение адреса прокси, параметров, вкладов, суммы и ERC-20 баланса.
- Взнос за другого адреса с `msg.sender` как плательщиком и возврат именно получателю вклада.
- Обычный взнос работает после обновления; проверки параметров V2.
- Неавторизованный upgrade запрещён; инициализаторы V1/V2 закрыты.

## 7. Сдача через GitHub

Когда **все три** проверки (`forge build`, `forge test`, `npm run validate:upgrade`) завершатся успешно, опубликуйте проект:

```bash
git add .
git commit -m "Implement TripFund and proxy upgrade bonus"
# Создайте ПУСТОЙ репозиторий в GitHub и скопируйте его URL:
git branch -M main
git remote add origin <GITHUB_REPO_URL>
git push -u origin main
```

Проверьте, что в коммит добавлены `.gitmodules` и записи сабмодулей из `lib/`, созданные командой `forge install`. Тогда `git submodule update --init --recursive` сможет установить их на другом компьютере. Не загружайте `node_modules`, `out`, `cache`, приватные ключи и `.env`. Преподавателю сдайте **ссылку на GitHub-репозиторий** — именно так указано в задании.

## 8. Что важно перед реальной эксплуатацией

Это учебный контракт, не прошедший внешний аудит. Он рассчитан на обычный ERC-20 без fees/rebasing и не включает аварийный вывод случайно присланных токенов (по заданию они **должны оставаться на контракте**). Администратор Transparent Proxy технически может заменить логику, несмотря на отсутствие setter-функций у V1; это осознанное свойство бонуса с обновлением.

Официальные материалы:

- https://docs.openzeppelin.com/contracts/5.x/api/token/erc20
- https://docs.openzeppelin.com/contracts/5.x/api/proxy
- https://docs.openzeppelin.com/upgrades-plugins/foundry/foundry-upgrades
- https://book.getfoundry.sh/
