# TripFund — ДЗ №2 «Сбор на поездку команды»

[← Все домашние работы курса](../../README.md)

Домашнее задание по Solidity. Подготовлена реализация базовых требований **TripFund** (до 10 баллов) и бонуса **V2 / Transparent Proxy / проверка совместимости OpenZeppelin Upgrades** (до 3 дополнительных баллов). Итоговая оценка зависит от успешного запуска тестов и проверки преподавателем.

> **Проверено 21.10.2026 после переноса:** свежий клон общего репозитория → `make hw02-setup` из корня → успешная сборка, **30 passed / 0 failed / 0 skipped**, fuzz **256 runs**, OpenZeppelin V1 → V2 **SUCCESS**. Подробности — в `REVIEW_REPORT.md`. Актуальный статус CI: [GitHub Actions](https://github.com/elinnlle/web3-course/actions/workflows/hw02-tripfund.yml).

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

Понадобится интернет для **первой** загрузки зависимостей. Работа находится в `homeworks/hw02-tripfund/` общего репозитория `web3-course`. Solidity-библиотеки подключены сабмодулями; скрипт восстанавливает их фиксированные commits из корневого `.gitmodules`.

1. Установите Foundry (`forge`), Git и Node.js 20+ (с npm).
2. Откройте терминал **в папке `homeworks/hw02-tripfund/`** клонированного репозитория.
3. Выполните **одну команду**:

```bash
bash scripts/setup.sh
```

Скрипт находит корень Git-репозитория курса, восстанавливает **только сабмодули HW02** и их вложенные зависимости, затем выполняет `npm ci` и все три проверки. В других домашних работах зависимости не устанавливаются. ZIP без Git-метаданных не поддерживается — используйте клонирование.

```bash
forge build --force
forge test --force -vv
npm run validate:upgrade
```

### Проверка после свежего клонирования

Клонирование общего репозитория и запуск этой домашней работы:

```bash
git clone https://github.com/elinnlle/web3-course.git web3-course
cd web3-course/homeworks/hw02-tripfund
bash scripts/setup.sh
```

`--recurse-submodules` при клонировании необязателен: setup восстанавливает зависимости этой работы самостоятельно. Из корня курса эквивалентная команда — `make hw02-setup` (или `bash homeworks/hw02-tripfund/scripts/setup.sh`). Для повторной проверки из корня: `make hw02-check`.

Версии сабмодулей закреплены commit SHA в Git, npm-пакеты — в `package-lock.json`. RPC, кошелёк, приватный ключ и `.env` для проверок не требуются.

Для повторного запуска без переустановки зависимостей:

```bash
bash scripts/check.sh
```

OpenZeppelin Foundry Upgrades действительно проверяет безопасность реализации и V1 → V2 storage layout: в конфигурации включены `ffi`, `ast`, `build_info`, `storageLayout`, а в V2 указана `@custom:oz-upgrades-from TripFund`. Проверка **не** выключена, `unsafeSkipAllChecks` не применяется. `--force` обновляет build info для CLI при каждом запуске тестов.

**Локальные проверки уже пройдены.** После публикации проверьте зелёный статус **HW02 TripFund (build, tests, V1 to V2)** в разделе Actions на GitHub. Скрипт ничего не публикует самостоятельно.

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
├── REVIEW_REPORT.md            # Сверка с требованиями и риски
└── README.md
```

Корневой `.gitmodules` находится [на уровне курса](../../.gitmodules), workflow — [`.github/workflows/hw02-tripfund.yml`](../../.github/workflows/hw02-tripfund.yml). Относительные пути в Foundry и remappings отсчитываются от папки этой домашней работы.

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

Домашняя работа публикуется **в составе общего репозитория `web3-course`**, а не как отдельный Git-репозиторий. Навигация по курсу и порядок сдачи находятся в [корневом README](../../README.md#проверки-и-сдача).

Преподавателю передайте ссылку вида `https://github.com/elinnlle/web3-course/tree/main/homeworks/hw02-tripfund` и, при необходимости, ссылку на зелёный запуск **HW02 TripFund (build, tests, V1 to V2)**. Карта требований 1–12 находится в [REVIEW_REPORT.md](REVIEW_REPORT.md).

Сабмодули, lock-файл, контракты, тесты и настройки включены в общий Git-репозиторий. `node_modules`, `out`, `cache`, логи, ключи и `.env.*` исключаются корневым `.gitignore` также во вложенных папках.

## 8. Что важно перед реальной эксплуатацией

Это учебный контракт, не прошедший внешний аудит. Он рассчитан на обычный ERC-20 без fees/rebasing и не включает аварийный вывод случайно присланных токенов (по заданию они **должны оставаться на контракте**). Администратор Transparent Proxy технически может заменить логику, несмотря на отсутствие setter-функций у V1; это осознанное свойство бонуса с обновлением.

Официальные материалы:

- https://docs.openzeppelin.com/contracts/5.x/api/token/erc20
- https://docs.openzeppelin.com/contracts/5.x/api/proxy
- https://docs.openzeppelin.com/upgrades-plugins/foundry/foundry-upgrades
- https://book.getfoundry.sh/
