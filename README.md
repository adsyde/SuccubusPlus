# Succubus Plus

Succubus Plus adds a succubus class to Baldur's Gate 3, with three subclasses: Nightmare, Spider Queen and Temptress. The mod includes English and Russian text.

**Version 1.0.0.60 is a testing release.** Desire accumulation has been checked in game; other mechanics and mod combinations still need testing.

The repository contains the resource snapshot used to package version 1.0.0.60. Some resources are in the game's compiled formats; original editable artwork and a full authoring pipeline are not included.

## Requirements and installation

- Baldur's Gate 3 and [BG3 Script Extender](https://github.com/Norbyte/bg3se).
- A level-cap mod is needed for levels 13–20.
- 5eSpells and Valkrana's Spellbook are optional.
- The original Succubus class is not required. Do not enable both versions together.

Install `SuccubusPlus.pak` with your mod manager and enable it in your load order. Back up your saves before changing your mod setup.

## Building

Install Python 3 and [LSLib / Divine](https://github.com/Norbyte/lslib), then run:

```powershell
python build.py --divine "C:\Tools\LSLib\Tools\Divine.exe"
```

The script creates `build/SuccubusPlus.pak`, unpacks it and checks every resource against the snapshot. Change the Divine path to match your installation. It refuses to overwrite an existing package.

## Credits

Inspired by Succubus — new class by Viper_Rogue. The class includes adapted data from the original mod. Developed by AdSyDe with AI assistance.

---

Succubus Plus добавляет в Baldur's Gate 3 класс суккуба с тремя подклассами: Кошмар, Королева пауков и Искусительница. Мод поддерживает русский и английский языки.

**Версия 1.0.0.60 — тестовая.** Накопление желания проверено в игре; остальные механики и сочетания модов требуют дополнительной проверки.

В репозитории находится набор ресурсов, из которого упакована версия 1.0.0.60. Часть ресурсов хранится в скомпилированных игровых форматах; исходные редактируемые изображения и полный процесс их создания не включены.

## Требования и установка

- Baldur's Gate 3 и [BG3 Script Extender](https://github.com/Norbyte/bg3se).
- Для уровней 13–20 нужен мод, снимающий ограничение уровня.
- 5eSpells и Valkrana's Spellbook необязательны.
- Оригинальный класс Succubus не требуется. Не включайте обе версии одновременно.

Установите `SuccubusPlus.pak` через менеджер модов и включите его в порядке загрузки. Перед изменением набора модов сохраните резервную копию сохранений.

## Сборка

Установите Python 3 и [LSLib / Divine](https://github.com/Norbyte/lslib), затем выполните:

```powershell
python build.py --divine "C:\Tools\LSLib\Tools\Divine.exe"
```

Скрипт создаст `build/SuccubusPlus.pak`, распакует его и сверит каждый ресурс с набором в репозитории. Укажите свой путь к Divine. Существующий пакет скрипт не перезаписывает.

## Авторы

Вдохновлён модом Succubus — new class автора Viper_Rogue. Класс содержит переработанные данные исходного мода. Succubus Plus разработан AdSyDe с помощью ИИ.
