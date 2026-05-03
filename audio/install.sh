if [[ "$(which pyinstaller)" == "" ]]; then
  echo "please install pyinstaller first!"
  exit
fi
pyinstaller --windowed --onefile --name "Audio" audio.py
rm -rf ../Open\ Wallpaper\ Engine/Resources/Audio.app
mv dist/Audio.app ../Open\ Wallpaper\ Engine/Resources/
rm -rf build dist Audio.spec
