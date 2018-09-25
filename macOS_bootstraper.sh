#!/bin/sh

macOS_bootstrap="$(pwd -P)"

export HOMEBREW_CASK_OPTS="--appdir=/Applications"
# export RBENV_ROOT=/usr/local/var/rbenv
# export NVM_DIR=/usr/local/var/nvm

red=$(tput setaf 1)
green=$(tput setaf 2)
color_reset=$(tput sgr0)

error_echo() {
  printf "\n${red}%s.${color_reset}\n" "$1"
}

info_echo() {
  printf "\n${green}%s ...${color_reset}\n" "$1"
}

version() {
  echo "$@" | awk -F. '{ printf("%d%03d%03d%03d\n", $1,$2,$3,$4); }'
}

catch_exit() {
  ret=$?
  test $ret -ne 0 && error_echo "Installation fails" >&2
  exit $ret
}

# ====================
# Check macOS version
# ====================

required_osx_version="10.14.0"
osx_version=$(/usr/bin/sw_vers -productVersion)

info_echo "Checking OS X version"
if [ "$(version "$osx_version")" -lt "$(version "$required_osx_version")" ]; then
  error_echo "Your OS X $osx_version version is older then required $required_osx_version version. Exiting"
  exit
fi

# ====================
# update macOS version
# ====================

info_echo "Running OS X Software updates"
sudo softwareupdate -i -a

# ====================
# setting up ssh
# ====================

info_echo "Checking for SSH key, generating one if it doesn't exist"
[[ -f ~/.ssh/id_rsa.pub ]] || ssh-keygen -t rsa

info_echo "Copying public key to clipboard. Paste it into your Github account"
[[ -f ~/.ssh/id_rsa.pub ]] && pbcopy < ~/.ssh/id_rsa.pub
open https://github.com/account/ssh

# ====================
# install brew and apps
# ====================

if test ! "$(which brew)"; then
  info_echo "Install Homebrew, a good OS X package manager"
  ruby -e "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/master/install)"
else
  info_echo "Update Homebrew"
  brew update
fi

info_echo "Install Brew formalue"
brew tap "Homebrew/bundle" 2> /dev/null
brew bundle --file="./Brewfile"

# https://github.com/eventmachine/eventmachine/issues/602#issuecomment-152184551
info_echo "Link keg-only openssl to /usr/local to let software outside of Homebrew to find it"
brew unlink openssl && brew link openssl --force

info_echo "Link Curl with openssl"
brew link --force curl

info_echo "Remove outdated versions from the cellar"
brew cleanup

# ====================
# setting up zsh with oh-my-zsh
# ====================

sh -c "$(curl -fsSL https://raw.githubusercontent.com/robbyrussell/oh-my-zsh/master/tools/install.sh)"
sudo chsh -s $(which zsh) $(whoami)

# ====================
# setting up ruby env
# ====================

info_echo "Enable rbenv alias"
eval "$(rbenv init -)"

info_echo "Set default gems list"
echo "bundler" >> "$(brew --prefix rbenv)/default-gems"
echo "tmuxinator" >> "$(brew --prefix rbenv)/default-gems"
echo "rails" >> "$(brew --prefix rbenv)/default-gems"
echo "powder" >> "$(brew --prefix rbenv)/default-gems"

ruby_version="2.5.1"

if test -z "$(rbenv versions --bare|grep $ruby_version)"; then
  info_echo "Install Ruby $ruby_version"
  rbenv install $ruby_version
fi

info_echo "Set Ruby $ruby_version as global default Ruby"
rbenv global $ruby_version

info_echo "Update to latest Rubygems version"
gem update --system --no-document

# ====================
# setting up node env
# ====================

info_echo "Enable NVM alias"
# we need disable -e during sourcing nvm.sh b/c of
# https://github.com/creationix/nvm/issues/721
# https://github.com/travis-ci/travis-ci/issues/3854#issuecomment-99492695
set +e
source "$(brew --prefix nvm)/nvm.sh"
set -e

if test -z "$(nvm ls|grep "node")"; then
  info_echo "Install Node.js LTS version"
  nvm install --lts
fi

info_echo "Set latest Node.js version as global default Node"
nvm use --lts
# nvm alias default --lts

export npm_config_global=true
export npm_config_loglevel=silent

# ====================
# restore from mackup
# ====================

# TODO

# ====================
# config macOS defaults
# ====================

info_echo "Set OS X defaults"

###############################################################################
# Trackpad, mouse, keyboard, Bluetooth accessories, and input                 #
###############################################################################

# Disable auto-correct
defaults write NSGlobalDomain NSAutomaticSpellingCorrectionEnabled -bool false

# Enable full keyboard access for all controls
# (e.g. enable Tab in modal dialogs)
defaults write NSGlobalDomain AppleKeyboardUIMode -int 3

# Disable Press and hold function
defaults write NSGlobalDomain ApplePressAndHoldEnabled -bool false

# shorter initial key repeat waiting time
defaults write NSGlobalDomain InitialKeyRepeat -int 12

# Faster key repeat speed
defaults write NSGlobalDomain KeyRepeat -int 1

###############################################################################
# Finder                                                                      #
###############################################################################

# Finder: show all filename extensions
defaults write NSGlobalDomain AppleShowAllExtensions -bool true

# Finder: show status bar
defaults write com.apple.finder ShowStatusBar -bool true

# Finder: show path bar
defaults write com.apple.finder ShowPathbar -bool true

# Display full POSIX path as Finder window title
defaults write com.apple.finder _FXShowPosixPathInTitle -bool true

# When performing a search, search the current folder by default
defaults write com.apple.finder FXDefaultSearchScope -string "SCcf"

# Disable the warning when changing a file extension
defaults write com.apple.finder FXEnableExtensionChangeWarning -bool false

# Avoid creating .DS_Store files on network volumes
defaults write com.apple.desktopservices DSDontWriteNetworkStores -bool true

# Use list view in all Finder windows by default
# Four-letter codes for the other view modes: `icnv`, `clmv`, `Flwv`
defaults write com.apple.Finder FXPreferredViewStyle Nlsv

# Enable AirDrop over Ethernet and on unsupported Macs running Lion
defaults write com.apple.NetworkBrowser BrowseAllInterfaces -bool true

# Set $HOME as the default location for new Finder windows
# For other paths, use `PfLo` and `file:///full/path/here/`
defaults write com.apple.finder NewWindowTarget -string "PfLo"
defaults write com.apple.finder NewWindowTargetPath -string "file://${HOME}"

###############################################################################
# Dock, Dashboard, and hot corners                                            #
###############################################################################

# Wipe all (default) app icons from the Dock
# This is only really useful when setting up a new Mac, or if you don’t use
# the Dock to launch apps.
#
# defaults write com.apple.dock persistent-apps -array

# Add applications to Dock
#
# for app in \
#   System\ Preferences \
#   Safari \
#   HipChat \
#   iTerm \
#   Sublime\ Text
# do
#   defaults write com.apple.dock "persistent-apps" -array-add "<dict><key>tile-data</key><dict><key>file-data</key><dict><key>_CFURLString</key><string>/Applications/$app.app/</string><key>_CFURLStringType</key><integer>0</integer></dict></dict></dict>"
# done

# Disable Dashboard
defaults write com.apple.dashboard mcx-disabled -bool true

# Don’t automatically rearrange Spaces based on most recent use
defaults write com.apple.dock mru-spaces -bool false

# Make Dock icons of hidden applications translucent
defaults write com.apple.dock showhidden -bool true

###############################################################################
# Safari & WebKit                                                             #
###############################################################################

# Prevent Safari from opening ‘safe’ files automatically after downloading
defaults write com.apple.Safari AutoOpenSafeDownloads -bool false

# Show status bar
defaults write com.apple.Safari ShowStatusBar -bool true

# Enable the Develop menu and the Web Inspector in Safari
defaults write com.apple.Safari IncludeDevelopMenu -bool true
defaults write com.apple.Safari WebKitDeveloperExtrasEnabledPreferenceKey -bool true
defaults write com.apple.Safari com.apple.Safari.ContentPageGroupIdentifier.WebKit2DeveloperExtrasEnabled -bool true

# Add a context menu item for showing the Web Inspector in web views
defaults write NSGlobalDomain WebKitDeveloperExtras -bool true

###############################################################################
# Spotlight                                                                   #
###############################################################################

# Disable Spotlight indexing for any volume that gets mounted and has not yet
# been indexed before.
# Use `sudo mdutil -i off "/Volumes/foo"` to stop indexing any volume.
sudo defaults write /.Spotlight-V100/VolumeConfiguration Exclusions -array "/Volumes"

# Change indexing order and disable some file types
defaults write com.apple.spotlight orderedItems -array \
  '{"enabled" = 1;"name" = "APPLICATIONS";}' \
  '{"enabled" = 1;"name" = "SYSTEM_PREFS";}' \
  '{"enabled" = 1;"name" = "DIRECTORIES";}' \
  '{"enabled" = 1;"name" = "PDF";}' \
  '{"enabled" = 1;"name" = "FONTS";}' \
  '{"enabled" = 0;"name" = "DOCUMENTS";}' \
  '{"enabled" = 0;"name" = "MESSAGES";}' \
  '{"enabled" = 0;"name" = "CONTACT";}' \
  '{"enabled" = 0;"name" = "EVENT_TODO";}' \
  '{"enabled" = 0;"name" = "IMAGES";}' \
  '{"enabled" = 0;"name" = "BOOKMARKS";}' \
  '{"enabled" = 0;"name" = "MUSIC";}' \
  '{"enabled" = 0;"name" = "MOVIES";}' \
  '{"enabled" = 0;"name" = "PRESENTATIONS";}' \
  '{"enabled" = 0;"name" = "SPREADSHEETS";}' \
  '{"enabled" = 0;"name" = "SOURCE";}'

# Make sure indexing is enabled for the main volume
sudo mdutil -i on / > /dev/null

# Rebuild the index from scratch
sudo mdutil -E / > /dev/null

###############################################################################
# Terminal & iTerm 2                                                          #
###############################################################################

# Only use UTF-8 in Terminal.app
defaults write com.apple.terminal StringEncodings -array 4

# Don’t display the annoying prompt when quitting iTerm
defaults write com.googlecode.iterm2 PromptOnQuit -bool false

###############################################################################
# Kill affected applications                                                  #
###############################################################################

for app in "cfprefsd" "Dock" "Finder" "Safari"  "SystemUIServer" "iTerm"; do
  killall "${app}" > /dev/null 2>&1 || true
done
