# HW02 TripFund — отчёт проверки

## Организация web3-course

Домашняя работа перенесена в `homeworks/hw02-tripfund/`. Git-история сохранена; отдельный вложенный Git-репозиторий не создавался. Исходники, тесты, foundry.toml, remappings.txt, package.json и package-lock.json перенесены без изменения содержимого.

Корень курса содержит навигационный README, Makefile, общие `.gitignore`, `.gitmodules` и workflows. Внутри HW02 находятся собственные конфигурация, зависимости, скрипты и подробный README. Будущие работы могут иметь другие технологии и независимые команды.

- `.gitmodules`: пути изменены на `homeworks/hw02-tripfund/lib/...`; имена секций сохранены как стабильные внутренние идентификаторы Git. Важны поля `path` и gitlink SHA, а не совпадение имени секции с каталогом.
- `scripts/setup.sh`: определяет корень курса и префикс домашки, восстанавливает только три её сабмодуля и вложенные зависимости; проверяет Node.js 20+, использует `npm ci`. Не вызывает `git init` внутри домашки и не устанавливает библиотеки в корень курса. Требуется Git-клон; ZIP без метаданных не поддерживается.
- Foundry и npm работают из папки HW02, поэтому относительные remappings и `out/build-info` остаются прежними.
- Из корня: `make hw02-setup` и `make hw02-check`. Из домашки: `bash scripts/setup.sh` и `bash scripts/check.sh`.
- Workflow `.github/workflows/hw02-tripfund.yml`: Ubuntu, Node.js 22, Foundry v1.8.5; `working-directory: homeworks/hw02-tripfund`; установка только зависимостей HW02; build, test, validate:upgrade. Фильтры push/PR включают домашку, workflow, `.gitmodules`, `.gitignore`, Makefile; ручной запуск доступен.
- Корневые правила ignore применяются на любой глубине, включая домашки. Секреты, keystore, npm-зависимости, сборочные и временные артефакты не предназначены для коммита.

## Версии

Foundry **v1.8.5**; Solidity **0.8.27**, Cancun; forge-std **v1.16.2**; Foundry Upgrades **v0.4.2**; OpenZeppelin Contracts и Upgradeable **5.7.0**; Upgrades Core **1.46.0**. Версии и gitlink SHA сохранены. Npm-зависимости закреплены package-lock.json.

## Проверки

**21.10.2026** проверен свежий клон новой структуры, коммит (course layout commit). После него изменены только документы с результатами проверки.

Основной репозиторий склонирован командой `git clone --no-local` в новый каталог `web3-course-fresh-check` без сабмодулей, node_modules, out или cache. Затем **из корня** выполнен `make hw02-setup`: скрипт сам скачал все необходимые сабмодули с GitHub по закреплённым SHA, включая вложенный OpenZeppelin Contracts 5.7.0, и установил npm-пакеты по lock-файлу.

| Проверка | Результат |
|---|---|
| `make hw02-setup` в свежем клоне | Код 0 |
| `forge build --force` | 67 файлов, Solidity 0.8.27, Compiler run successful |
| `forge test --force -vv` | **30 passed, 0 failed, 0 skipped**: 22 базовых + 8 бонусных |
| Fuzz-тест | **256 runs** |
| `npm run validate:upgrade` | **SUCCESS**, TripFundV2 upgrades from TripFund |
| Git после установки и проверок | Чистое рабочее дерево |
| Расположение node_modules, out, cache | Только внутри HW02, не в корне курса |

Использованы установленные инструменты macOS arm64: Foundry 1.8.5, solc 0.8.27, Node.js 25.8.1 / npm 11.11.0. Общие кэши npm и компилятора могли использоваться; проверен свежий Git-клон, не новая ОС. CI настроен на Ubuntu / Node.js 22; фактический GitHub-run до публикации не подтверждён.

Дополнительно: Bash-синтаксис скриптов и YAML workflow проверены; Makefile содержит корректные setup/check-команды; ссылки двух README существуют; ignore-правила срабатывают для вложенных артефактов и секретов. Проверка типичных токенов/ключей по доступной истории собственных файлов не нашла совпадений. В Git нет node_modules, out, cache и временных файлов. Это не гарантия от будущего добавления секретов; содержимое отслеживаемых файлов нужно проверять перед коммитом.

Контракты, тесты, foundry.toml, remappings.txt, package.json и package-lock.json побайтно совпадают с версией до переноса. Проверки OpenZeppelin не отключались.

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

## Ограничения и публикация

Публикация не выполнялась, remote не настроен. После подтверждения владельца нужно создать пустой публичный GitHub-репозиторий `web3-course`, отправить `main`, проверить зелёный Actions именно для опубликованного коммита и передать преподавателю ссылку на `homeworks/hw02-tripfund/`.

GitHub Actions до публикации не запускался. Предупреждения Forge о block.timestamp ожидаемы: условия дедлайна прямо требуются заданием. Контракт рассчитан на обычный ERC-20 без fee/rebasing; внешний аудит не выполнялся. ProxyAdmin сохраняет предусмотренное бонусом право обновления. Прямые переводы остаются в контракте, totalRaised после возврата не уменьшается, право возврата V2 принадлежит beneficiary.

Окончательную оценку выставляет преподаватель; прохождение проверок не гарантирует балл.
