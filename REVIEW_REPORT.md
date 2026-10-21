# Проверка ДЗ №2 «Сбор на поездку» — 21.10.2026

## Финальная подготовка к сдаче — 21.10.2026

- Проверены все 19 отслеживаемых записей: исходники, тесты, документация, конфигурация, скрипты, lock-файл, workflow и три gitlink-записи библиотек присутствуют. Артефакты сборки и node_modules не отслеживаются.
- Проверка содержимого отслеживаемых файлов на типичные токены, приватные ключи и присвоенные секреты совпадений не нашла. До этой подготовки история состояла из одного исходного коммита. Это проверка конкретного содержимого, а не гарантия от будущего случайного добавления секретов.
- `.gitignore` дополнен правилами для `.env.*` (кроме шаблонов), файлов ключей/keystore, логов, временных каталогов, coverage и настроек редакторов. Правила проверены через `git check-ignore`; `.env.example` и `.env.sample` доступны для безопасных шаблонов без секретов.
- `.gitmodules` содержит публичные HTTPS-адреса; все основные и вложенные сабмодули восстановлены по закреплённым SHA. Изменение `.gitmodules` не требуется.
- `package-lock.json` соответствует `package.json`: 102 пакета, у каждого есть integrity hash, все tarball URL ведут на registry.npmjs.org.
- YAML GitHub Actions успешно разобран и проверен: push / pull_request / workflow_dispatch; рекурсивный checkout; Node.js 22; Foundry v1.8.5; права contents: read; вызов `bash scripts/setup.sh`. Цепочка setup → check выполняет `forge build --force`, `forge test --force -vv`, `npm run validate:upgrade`. `set -euo pipefail` делает ошибку любой команды ошибкой CI. Изменение workflow не требуется.

### Воспроизведение из свежего клона

Проверен коммит `2d5fb70`; последующие изменения подготовки затрагивают только `.gitignore`, README и этот отчёт. Контракты, тесты, зависимости, настройки сборки и CI не изменены.

```bash
git clone --no-local ./TripFund-Homework-2 ./tripfund-submission-check
cd ./tripfund-submission-check
git submodule update --init --recursive --depth 1 --jobs 4
bash scripts/setup.sh
```

Основной репозиторий клонирован локально, поскольку удалённый ещё не создан; все сабмодули скачаны с GitHub заново. Перед setup в клоне отсутствовали `node_modules`, `out` и `cache`. Использованы ранее установленные Foundry 1.8.5, solc 0.8.27 и Node.js 25.8.1, а также общий кэш npm; это проверка свежего репозитория, не новой операционной системы.

Результат: **код 0**, сборка 67 файлов успешна, **30 passed / 0 failed / 0 skipped**, fuzz — **256 runs**, OpenZeppelin CLI — **SUCCESS**. `git status --porcelain` после полного setup пуст. Рабочие контракты и тесты не изменялись, проверки OpenZeppelin не отключались.

### Готовность к публикации

Технических препятствий не обнаружено. README дополнен командами свежего клонирования и последовательностью публикации/сдачи. Репозиторий подготовлен локально на `main`; remote не настроен, публикация не выполнялась. После подтверждения владельца нужно создать пустой GitHub-репозиторий, отправить main, дождаться зелёного Actions именно для отправленного коммита и передать преподавателю ссылку. Прогон на Ubuntu / Node.js 22 в GitHub Actions до публикации не подтверждён.

## Результат первоначальной проверки 16.10.2026

Полный `bash scripts/setup.sh` завершён с кодом **0** на macOS arm64.

| Команда | Результат |
|---|---|
| `forge build --force` | 67 файлов, Solc 0.8.27, `Compiler run successful!` |
| `forge test --force -vv` | **30 passed, 0 failed, 0 skipped**: 22 базовых + 8 upgrade-тестов |
| Fuzz в составе тестов | `testFuzz_RepeatedContributionsAccumulate`: 256 успешных прогонов |
| `npm run validate:upgrade` | **SUCCESS**: `TripFundV2 (upgrades from TripFund)` |

Контрактные исходники, тесты, remappings и настройки компилятора не изменялись. Проверки OpenZeppelin не отключались. Существующая аннотация `@custom:oz-upgrades-unsafe-allow constructor` разрешает только конструктор с `_disableInitializers()`; она не отключает проверку storage layout или остальные проверки безопасности.

## Окружение и зависимости

- Установлен Foundry **v1.8.5**, commit `51a52c59cffd940f76eddd0b4bb1791aa4b5ac7f`: forge, cast, anvil, chisel, каталог `~/.foundry/bin`. PATH добавлен в `~/.zprofile`.
- Node.js **v25.8.1** и npm **11.11.0** уже были установлены; переустановка не требовалась. CI использует Node.js 22.
- Установлен Solidity **0.8.27+commit.40a35a09** в стандартный кэш SVM. EVM: Cancun; optimizer: 200 runs.
- Установлен `@openzeppelin/upgrades-core` **1.46.0** и его npm-зависимости. Создан `package-lock.json`.

| Solidity-зависимость | Тег | Commit SHA |
|---|---|---|
| forge-std | v1.16.2 | `bf647bd6046f2f7da30d0c2bf435e5c76a780c1b` |
| OpenZeppelin Contracts Upgradeable | v5.7.0 | `14f52c54d3a1eefbda3d4071efba24d3c1e07e8a` |
| Вложенный OpenZeppelin Contracts | v5.7.0 | `cab19933c33c2ad1d4c7a84864a3601dddfd16f3` |
| OpenZeppelin Foundry Upgrades | v0.4.2 | `8ddceb0c0d94f7f9420fee1ee30fffbdacadf08f` |

Вложенные служебные копии forge-std сохраняют версии, выбранные авторами библиотек. Remapping проекта `forge-std/` разрешается в основную копию v1.16.2.

### Устранённая проблема окружения

Штатная загрузка solc в Foundry оборвалась с ошибкой TLS: `peer closed connection without sending TLS close_notify`. Официальный бинарник был скачан через curl с возобновлением загрузки, проверен по SHA-256 из официального `list.json` и помещён в кэш SVM. После этого полный setup прошёл успешно. Изменений логики проекта для обхода ошибки не понадобилось.

Проверенные SHA-256:

- Foundry darwin_arm64 v1.8.5: `56049728e25e44a61c7f2e49438023b0890cb45850ffcb7c882f90cd998baf83`.
- solc macosx-amd64 0.8.27: `8c406fa5cab9bd0a175da02c652072f814c3d06205a2fd6d92bc152599a6aabb`.

## Сверка с оригинальным заданием

Прочитан исходный двухстраничный PDF `ДЗ №2 Базовый. Сбор на поездку.pdf` из Downloads. Ниже — проверка именно его пунктов, а не только README. Имена тестов сокращены без префикса `test_`; базовые находятся в `test/TripFund.t.sol`, бонусные — в `test/TripFundUpgrade.t.sol`.

| № | Требование | Подтверждение | Итог |
|---|---|---|---|
| 1 | token, organizer, goal, deadline; валидация, отсутствие setter-функций | `InitializationAndImmutableConfigurationByInterface`, `RejectsInvalidInitializationParameters`; параметры задаются атомарно при создании прокси | Выполнен |
| 2 | Взнос > 0 до дедлайна, approve, safeTransferFrom у msg.sender, накопление | `TwoContributorsRepeatedPaymentsAndBalances`, `ApproveMustTargetProxyNotImplementation`, fuzz; проверен `SafeERC20` в исходнике | Выполнен |
| 3 | Читаемые contributions и исторический totalRaised; прямые переводы не учитываются и не распределяются | Тесты накопления, возвратов, вывода и прямых переводов; totalRaised не уменьшается | Выполнен |
| 4 | После срока: однократный вывод организатору при успехе либо полный личный возврат при провале | `ExactGoalAllowsOnlyOrganizerToWithdrawOnce`, `FailedCampaignIndependentFullRefundsAndWrongOutcome`, `CannotSettleEarlyEvenWhenGoalMet` | Выполнен |
| 5 | SafeERC20, effects до внешних вызовов, откат при ошибке, обнуление/флаг, события | `FailedPayoutTransferRollsBackWithdrawnFlag`, `FailedPayoutTransferRollsBackRefundZeroing`, тесты событий и откатов; ревью порядка операций | Выполнен |
| 6 | Два участника, повторные взносы, нулевая сумма, баланс/allowance без изменения состояния при ошибке | `TwoContributorsRepeatedPaymentsAndBalances`, `RejectsZeroContributionWithoutChangingAccounting`, тесты недостаточных баланса/allowance | Выполнен |
| 7 | deadline − 1 проходит, deadline отклоняется; досрочные выплаты запрещены даже при успехе | `DeadlineMinusOneSecondWorks_ExactDeadlineDoesNot`, `CannotSettleEarlyEvenWhenGoalMet` | Выполнен |
| 8 | Ровно goal, больше goal, недобор; балансы, запрет чужих/повторных выплат и неверного исхода | `ExactGoalAllowsOnlyOrganizerToWithdrawOnce`, `OverGoalWithdrawsFullAccountedAmount`, `FailedCampaignIndependentFullRefundsAndWrongOutcome` | Выполнен |
| 9 | Прямой перевод не меняет totalRaised и остаётся после выплат | `DirectTransfersIgnoredAndRemainAfterSuccessfulPayout`, `DirectTransfersIgnoredAndRemainAfterFailedRefunds` | Выполнен |
| 10 | Transparent Proxy OZ 5.x с initialize, storage, блокировка реализации/повторной инициализации, только владелец ProxyAdmin обновляет | V1 развёрнут через `Upgrades.deployTransparentProxy`; `CannotReinitializeProxyOrImplementation`, `NonOwnerCannotUpgradeAndInitializersStayLocked` | Выполнен |
| 11 | Обновление до срока, contributeFor: payer = msg.sender, права у beneficiary, проверки и событие | Тесты V2: взносы за друга, повторные платежи, событие, нулевые параметры, дедлайн, баланс/allowance; возврат получает друг | Выполнен |
| 12 | OpenZeppelin storage validation; адрес/состояние/баланс сохранены; gift/refund, старый contribute, запреты upgrade/initialize | `V1Contribution_ValidatedUpgrade_StatePreserved_GiftAndRefund`, `NonOwnerCannotUpgradeAndInitializersStayLocked`; CLI — SUCCESS | Выполнен |

Проверки выполняют настоящий `Upgrades.upgradeProxy` с `tryCaller = PROXY_OWNER`. Отказ чужому владельцу проверяется на `ProxyAdmin.upgradeAndCall`. В V2 нет новых переменных storage; используется `@custom:oz-upgrades-from TripFund`. `ffi`, `ast`, `build_info`, `storageLayout` включены. В проектном коде нет `unsafeSkipAllChecks` или `UnsafeUpgrades`.

## Изменённые файлы и подготовка GitHub

- `scripts/setup.sh`: использует `npm ci`, если lock-файл существует; первоначальная установка без lock-файла сохранена.
- `package-lock.json`: фиксирует все npm-зависимости.
- `.gitmodules` и три gitlink-записи `lib/`: фиксируют Solidity-зависимости и их точные commits.
- `.github/workflows/solidity.yml`: Foundry закреплён на проверенной v1.8.5 вместо плавающего stable.
- `README.md`: фактические результаты, версии и воспроизводимая установка.
- `REVIEW_REPORT.md`: этот отчёт вместо предварительного ревью без запуска.
- Вне проекта: установлен Foundry/solc, обновлён PATH в `~/.zprofile`.

Локальный репозиторий подготовлен на ветке `main`. `node_modules`, `out`, `cache`, `broadcast`, `.env` и `.DS_Store` исключены из Git. Публикация и создание GitHub-репозитория не выполнялись. Условие сдачи ссылкой на GitHub будет выполнено только после разрешённой публикации; статус GitHub Actions пока не проверен.

## Предупреждения и ограничения

- Forge выдал четыре lint-предупреждения `block-timestamp`: сравнение времени прямо требуется заданием. Проверки дедлайна не изменялись и предупреждения не подавлялись.
- Первый build сообщил об отсутствии необязательного локального кэша сигнатур Foundry; это не повлияло на компиляцию и тесты.
- Контракт предназначен для обычного ERC-20 без fee/rebasing; внешний аудит не выполнялся.
- Владелец ProxyAdmin может заменить логику. Это предусмотренная бонусом административная возможность, отличная от роли organizer.
- Случайно переведённые токены остаются в контракте по условию задания; механизма спасения этих токенов нет.
- Первая установка на другой машине требует доступа к GitHub, npm и хранилищу solc. На текущей машине все зависимости установлены.

Окончательную оценку выставляет преподаватель; прохождение тестов не является обещанием балла.
