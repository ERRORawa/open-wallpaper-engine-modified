if [[ "$(which pyinstaller)" == "" ]]; then
  echo "please install pyinstaller"
  exit
fi
if [[ "$(find ./audio.py)" == "" ]]; then
  echo "audio.py not found"
  exit
fi
pyinstaller --windowed --onefile --name "Audio" audio.py
rm -rf ../Open\ Wallpaper\ Engine/Resources/Audio.app
mv dist/Audio.app ../Open\ Wallpaper\ Engine/Resources/
rm -rf build dist Audio.spec
