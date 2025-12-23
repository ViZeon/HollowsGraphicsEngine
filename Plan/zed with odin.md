1. Install <@353210479578972160>'s Zed-Odin extension
  - you can `git clone https://codeberg.org/Sylphrena/Zed-Odin`, or just go to the url at <https://codeberg.org/Sylphrena/Zed-Odin> and download the whole thing as a zip
  - Unzip if if you downloaded it as a zip
2. Install rustup
  - To see if you already have it installed, just open a terminal and type `rustup`
  - If not, go to <https://rustup.rs/>
  - You should be able to just run that exe and hit enter a few times, it'll all install
  - Make sure you close and reopen your terminal for the install to work
3. Inside Zed, go to the extensions panel
  - 3 lines in the top left, Zed, Extensions
4. Click `Install Dev Extension`
  - Open the extension folder
5. Wait around, it might take several seconds. There's a loading bar in the bottom left
6. Clone the ols repository, <https://github.com/danielgavin/ols>. Feel free to do this step while you wait for the extension
  - If you need to build ols, Inside that directory run `./build.bat`
  - If you need to build odinfmt, inside that directory run `./odinfmt.bat`
6. Open your settings JSON file, `Ctrl+Alt+,`, or under the 3 lines menu in the top left
  - Add the following 2 blocks:
```json
"lsp": {
      "ols":{
          "settings":{
              "path": "Your/Path/To/ols.exe"
          }
      }
  },
```
```json
"languages": {
    "Odin": {
      "formatter":{
        "external": {
          "command": "Your/Path/To/odinfmt.exe",
          "arguments": ["-stdin"]
        }
      }
    }
  }
```
Should be all good, obviously replace "Your/Path/To" with the actual path you clone ols to

instructions by: rats159
https://www.rats159.dev/