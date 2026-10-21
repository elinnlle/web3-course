# web3-course

Домашние задания университетского курса Web3. Каждая работа — самостоятельный проект со своими зависимостями, технологиями, настройками и инструкциями.

## Домашние работы

| № | Работа | Технологии | Что реализовано |
|---|---|---|---|
| 02 | [TripFund — сбор на поездку](homeworks/hw02-tripfund/README.md) | Solidity 0.8.27, Foundry, OpenZeppelin | Взносы ERC-20, выплата организатору или возвраты; бонус: Transparent Proxy, V2 `contributeFor`, проверка совместимости хранилища |

## Быстрый запуск HW02

Нужны Git, Foundry **v1.8.5**, Node.js **20+** и npm. Для первой установки нужен интернет. RPC, кошелёк, приватные ключи и `.env` не требуются.

```bash
git clone https://github.com/elinnlle/web3-course.git web3-course
cd web3-course
make hw02-setup
```

`make hw02-setup` восстанавливает только сабмодули HW02 (включая вложенные), устанавливает npm-пакеты по lock-файлу и выполняет:

```text
forge build --force
forge test --force -vv
npm run validate:upgrade
```

Для повторной проверки: `make hw02-check`.

Без Make, непосредственно из папки работы:

```bash
cd homeworks/hw02-tripfund
bash scripts/setup.sh  # зависимости и все проверки
bash scripts/check.sh  # повторные проверки
```

Можно также клонировать все сабмодули курса сразу: `git clone --recurse-submodules https://github.com/elinnlle/web3-course.git web3-course`. ZIP-архив без Git-метаданных не поддерживается скриптом установки: используйте `git clone`.

**Проверено 21.10.2026 в свежем клоне:** `make hw02-setup` — код 0; сборка успешна, 30 тестов пройдены (256 fuzz-прогонов), OpenZeppelin V1 → V2 — SUCCESS. [Подробный отчёт](homeworks/hw02-tripfund/REVIEW_REPORT.md).

## Организация

```text
web3-course/
├── README.md
├── Makefile
├── .gitignore
├── .gitmodules
├── .github/workflows/
│   └── hw02-tripfund.yml
└── homeworks/
    └── hw02-tripfund/
        ├── README.md
        ├── REVIEW_REPORT.md
        ├── src/
        ├── test/
        ├── lib/                 # Git-сабмодули этой работы
        ├── scripts/
        ├── foundry.toml
        ├── remappings.txt
        ├── package.json
        └── package-lock.json
```

## Проверки и сдача

[Workflow HW02](.github/workflows/hw02-tripfund.yml) запускается при push/PR, затрагивающем HW02 или её инфраструктуру, а также вручную через Actions. Он устанавливает только инструменты и зависимости этой работы и проверяет сборку, тесты и совместимость V1 → V2. Ошибка любой проверки останавливает workflow.

Преподавателю удобно передать ссылку непосредственно на **`homeworks/hw02-tripfund/`** в GitHub, дополнительно — ссылку на успешный запуск **HW02 TripFund (build, tests, V1 to V2)**. Подробные требования, примеры и карта пунктов 1–12 находятся внутри работы.

Актуальный статус автоматических проверок: [GitHub Actions](https://github.com/elinnlle/web3-course/actions/workflows/hw02-tripfund.yml).

## Следующие домашние работы

- Добавляйте независимые проекты в `homeworks/hw03-<название>/`, `homeworks/hw04-<название>/` и далее, обновляя таблицу навигации.
- Храните README, lock-файлы, зависимости и команды запуска внутри соответствующей работы. Общего npm/Foundry-проекта в корне нет; будущие работы могут использовать любые технологии.
- Для каждой работы добавляйте отдельный workflow с её инструментами, `working-directory` и фильтрами путей. Команды в корневом Makefile — необязательные удобные ярлыки.
- Git-репозиторий один: не запускайте `git init` внутри домашек. Если нужны сабмодули, регистрируйте их в корневом `.gitmodules` с полным путём `homeworks/hwNN-<название>/...` и фиксируйте commit SHA.
- Корневой `.gitignore` исключает секреты и распространённые артефакты на любой глубине. Специфичные для технологии исключения добавляйте в `.gitignore` соответствующей домашки. Не помещайте секреты в отслеживаемые файлы или шаблоны окружения.
