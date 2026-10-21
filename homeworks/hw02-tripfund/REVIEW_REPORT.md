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

До переноса прошли сборка, 30 тестов (256 fuzz-прогонов) и OpenZeppelin V1 → V2 validation. Результат свежего клона новой структуры будет зафиксирован после повторного запуска.

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
