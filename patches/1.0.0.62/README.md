# Патч Succubus Plus 1.0.0.62 для владельцев .61

Этот скрипт локально собирает тестовую .62 из уже имеющейся .61 с указанной контрольной суммой. Архив патча содержит скрипт и инструкцию. Нужны Python 3, `Divine.exe` из [LSLib](https://github.com/Norbyte/lslib/releases) и исходный `SuccubusPlus.pak` версии .61.

Запустите из PowerShell в папке со скриптом, подставив пути к Divine и PAK.

```powershell
python .\apply_062.py --divine 'C:\Tools\LSLib\Tools\Divine.exe' --base 'C:\Path\To\SuccubusPlus.pak'
```

Рядом появится `SuccubusPlus-1.0.0.62.pak`. Закройте игру и менеджер модов, сохраните копии прежнего PAK и сохранения, затем замените текущий `SuccubusPlus.pak` новым под тем же именем. Откройте менеджер и экспортируйте текущий порядок с новой версией. Для игры нужен BG3 Script Extender.

Оба режима «Воздушного поцелуя» проверяют подкласс Искусительницы до каста. Проверки сборки прошли. Работу в игре и появление кнопки у Кошмара еще предстоит проверить.

---

# Succubus Plus 1.0.0.62 patch for existing .61 users

This script builds the .62 test candidate from an existing copy of the exact .61 PAK. The patch archive contains the script and these instructions. You need Python 3, `Divine.exe` from [LSLib](https://github.com/Norbyte/lslib/releases), and the .61 `SuccubusPlus.pak`.

In PowerShell, run the command above from the script folder using your paths. The script checks the source PAK’s SHA-256 and writes `SuccubusPlus-1.0.0.62.pak` to the current folder. Close the game and mod manager, back up the previous PAK and your save, and replace `SuccubusPlus.pak` with the new file under the same name. Open the manager and export your current load order with the new version. The game requires BG3 Script Extender.

Both Blown Kiss variants now check for Temptress before casting. The build passed automated checks. In-game behavior and how Nightmare gained the spell still need confirmation.
