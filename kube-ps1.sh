#!/bin/bash

# Kubernetes prompt helper for bash/zsh
# Displays current context and namespace

# Copyright 2018 Jon Mosco
#
#  Licensed under the Apache License, Version 2.0 (the "License");
# you may not use this file except in compliance with the License.
# You may obtain a copy of the License at
#
#     http://www.apache.org/licenses/LICENSE-2.0
#
# Unless required by applicable law or agreed to in writing, software
# distributed under the License is distributed on an "AS IS" BASIS,
# WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
# See the License for the specific language governing permissions and
# limitations under the License.

# Debug
[[ -n $DEBUG ]] && set -x

# Default values for the prompt
# Override these values in ~/.zshrc or ~/.bashrc
KUBE_PS1_BINARY="${KUBE_PS1_BINARY:-kubectl}"
KUBE_PS1_SYMBOL_ENABLE="${KUBE_PS1_SYMBOL_ENABLE:-true}"
KUBE_PS1_SYMBOL_DEFAULT=${KUBE_PS1_SYMBOL_DEFAULT:-$'\u2388 '}
KUBE_PS1_SYMBOL_USE_IMG="${KUBE_PS1_SYMBOL_USE_IMG:-false}"
KUBE_PS1_NS_ENABLE="${KUBE_PS1_NS_ENABLE:-true}"
KUBE_PS1_PREFIX="${KUBE_PS1_PREFIX-(}"
KUBE_PS1_SEPARATOR="${KUBE_PS1_SEPARATOR-|}"
KUBE_PS1_DIVIDER="${KUBE_PS1_DIVIDER-:}"
KUBE_PS1_SUFFIX="${KUBE_PS1_SUFFIX-)}"
KUBE_PS1_SYMBOL_COLOR="${KUBE_PS1_SYMBOL_COLOR-blue}"
KUBE_PS1_CTX_COLOR="${KUBE_PS1_CTX_COLOR-red}"
KUBE_PS1_NS_COLOR="${KUBE_PS1_NS_COLOR-cyan}"
KUBE_PS1_BG_COLOR="${KUBE_PS1_BG_COLOR}"
KUBE_PS1_KUBECONFIG_CACHE="${KUBECONFIG}"
KUBE_PS1_DISABLE_PATH="${HOME}/.kube/kube-ps1/disabled"
KUBE_PS1_UNAME=$(uname)
KUBE_PS1_LAST_TIME=0

# Determine our shell
if [ "${ZSH_VERSION-}" ]; then
  KUBE_PS1_SHELL="zsh"
elif [ "${BASH_VERSION-}" ]; then
  if ((BASH_VERSINFO[0] < 4)); then
    return
  fi
  KUBE_PS1_SHELL="bash"
fi

_kube_ps1_shell_settings() {
  case "${KUBE_PS1_SHELL}" in
    "zsh")
      setopt PROMPT_SUBST
      autoload -U add-zsh-hook
      add-zsh-hook precmd _kube_ps1_update_cache
      zmodload zsh/stat
      ;;
    "bash")
      PROMPT_COMMAND="_kube_ps1_update_cache;${PROMPT_COMMAND:-:}"
      ;;
  esac
}

_kube_ps1_color_fg() {
  local ESC_OPEN
  local ESC_CLOSE
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    ESC_OPEN="%{"
    ESC_CLOSE="%}"
    case "${1}" in
      black|red|green|yellow|blue|cyan|white|magenta)
        echo "${ESC_OPEN}%F{$1}${ESC_CLOSE}";;
      [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        echo "${ESC_OPEN}%F{$1}${ESC_CLOSE}";;
      reset_color|"")
        echo "${ESC_OPEN}%f${ESC_CLOSE}";;
      *)
        echo "${ESC_OPEN}%f${ESC_CLOSE}";;
    esac
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    ESC_OPEN=$'\001'
    ESC_CLOSE=$'\002'
    # TODO: Cache these results for faster lookup
    if tput setaf 1 &> /dev/null; then
      case "${1}" in
        black)
          echo "${ESC_OPEN}$(tput setaf 0)${ESC_CLOSE}";;
        red)
          echo "${ESC_OPEN}$(tput setaf 1)${ESC_CLOSE}";;
        green)
          echo "${ESC_OPEN}$(tput setaf 2)${ESC_CLOSE}";;
        yellow)
          echo "${ESC_OPEN}$(tput setaf 3)${ESC_CLOSE}";;
        blue)
          echo "${ESC_OPEN}$(tput setaf 4)${ESC_CLOSE}";;
        magenta)
          echo "${ESC_OPEN}$(tput setaf 5)${ESC_CLOSE}";;
        cyan)
          echo "${ESC_OPEN}$(tput setaf 6)${ESC_CLOSE}";;
        white)
          echo "${ESC_OPEN}$(tput setaf 7)${ESC_CLOSE}";;
        reset_color|"")
          echo ${ESC_OPEN}$'\033[39m'${ESC_CLOSE};;
        [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
          echo "${ESC_OPEN}$(tput setaf ${1})${ESC_CLOSE}";;
        *)
          echo ${ESC_OPEN}$'\033[39m'${ESC_CLOSE};;
      esac
    else
      case "${1}" in
        black)
          echo ${ESC_OPEN}$'\033[30m'${ESC_CLOSE};;
        red)
          echo ${ESC_OPEN}$'\033[31m'${ESC_CLOSE};;
        green)
          echo ${ESC_OPEN}$'\033[32m'${ESC_CLOSE};;
        yellow)
          echo ${ESC_OPEN}$'\033[33m'${ESC_CLOSE};;
        blue)
          echo ${ESC_OPEN}$'\033[34m'${ESC_CLOSE};;
        magenta)
          echo ${ESC_OPEN}$'\033[35m'${ESC_CLOSE};;
        cyan)
          echo ${ESC_OPEN}$'\033[36m'${ESC_CLOSE};;
        white)
          echo ${ESC_OPEN}$'\033[37m'${ESC_CLOSE};;
        9[0-7])
          echo ${ESC_OPEN}$'\033['${1}m${ESC_CLOSE};;
        reset_color|"")
          echo ${ESC_OPEN}$'\033[39m'${ESC_CLOSE};;
        *)
          echo ${ESC_OPEN}$'\033[39m'${ESC_CLOSE};;
      esac
    fi
  fi
}

_kube_ps1_color_bg() {
  local ESC_OPEN
  local ESC_CLOSE
  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    ESC_OPEN="%{"
    ESC_CLOSE="%}"
    case "${1}" in
      black|red|green|yellow|blue|cyan|white|magenta)
        echo "${ESC_OPEN}%K{$1}${ESC_CLOSE}";;
      [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
        echo "${ESC_OPEN}%K{$1}${ESC_CLOSE}";;
      bg_close)
        echo "${ESC_OPEN}%k${ESC_CLOSE}";;
      *)
        echo "${ESC_OPEN}%K${ESC_CLOSE}";;
    esac
  elif [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    ESC_OPEN=$'\001'
    ESC_CLOSE=$'\002'
    if tput setaf 1 &> /dev/null; then
      case "${1}" in
        black)
          echo "${ESC_OPEN}$(tput setab 0)${ESC_CLOSE}";;
        red)
          echo "${ESC_OPEN}$(tput setab 1)${ESC_CLOSE}";;
        green)
          echo "${ESC_OPEN}$(tput setab 2)${ESC_CLOSE}";;
        yellow)
          echo "${ESC_OPEN}$(tput setab 3)${ESC_CLOSE}";;
        blue)
          echo "${ESC_OPEN}$(tput setab 4)${ESC_CLOSE}";;
        magenta)
          echo "${ESC_OPEN}$(tput setab 5)${ESC_CLOSE}";;
        cyan)
          echo "${ESC_OPEN}$(tput setab 6)${ESC_CLOSE}";;
        white)
          echo "${ESC_OPEN}$(tput setab 7)${ESC_CLOSE}";;
        [0-9]|[0-9][0-9]|[0-9][0-2][0-5])
          echo "${ESC_OPEN}$(tput setab ${1})${ESC_CLOSE}";;
        bg_close)
          echo "${ESC_OPEN}$(tput sgr 0)${ESC_CLOSE}";;
        *)
          echo "${ESC_OPEN}$(tput sgr 0)${ESC_CLOSE}";;
      esac
    else
      case "${1}" in
        black)
          echo ${ESC_OPEN}$'\033[40m'${ESC_CLOSE};;
        red)
          echo ${ESC_OPEN}$'\033[41m'${ESC_CLOSE};;
        green)
          echo ${ESC_OPEN}$'\033[42m'${COLOR_CLOSE};;
        yellow)
          echo ${ESC_OPEN}$'\033[43m'${ESC_CLOSE};;
        blue)
          echo ${ESC_OPEN}$'\033[44m'${ESC_CLOSE};;
        magenta)
          echo ${ESC_OPEN}$'\033[45m'${ESC_CLOSE};;
        cyan)
          echo ${ESC_OPEN}$'\033[46m'${ESC_CLOSE};;
        white)
          echo ${ESC_OPEN}$'\033[47m'${ESC_CLOSE};;
        10[0-7])
          echo ${ESC_OPEN}$'\033['${1}m${ESC_CLOSE};;
        bg_close)
          echo ${ESC_OPEN}$'\033[0m'${ESC_CLOSE};;
        *)
          echo ${ESC_OPEN}$'\033[0m'${ESC_CLOSE};;
      esac
    fi
  fi
}

_kube_ps1_set_colors() {
  if [[ -n "${KUBE_PS1_BG_COLOR}" ]]; then
    _KUBE_PS1_BG_COLOR="$(_kube_ps1_color_bg $KUBE_PS1_BG_COLOR)"
    _KUBE_PS1_BG_COLOR_CLOSE="$(_kube_ps1_color_bg bg_close)"
  fi

  _KUBE_PS1_RESET_COLOR="$(_kube_ps1_color_fg reset_color)"
  _KUBE_PS1_SYMBOL_COLOR="$(_kube_ps1_color_fg $KUBE_PS1_SYMBOL_COLOR)"
  _KUBE_PS1_CTX_COLOR="$(_kube_ps1_color_fg $KUBE_PS1_CTX_COLOR)"
  _KUBE_PS1_NS_COLOR="$(_kube_ps1_color_fg $KUBE_PS1_NS_COLOR)"
}

_kube_ps1_binary_check() {
  command -v $1 >/dev/null
}

_kube_ps1_symbol() {
  [[ "${KUBE_PS1_SYMBOL_ENABLE}" == false ]] && return

  local _KUBE_PS1_SYMBOL_IMG
  local _KUBE_PS1_SYMBOL_DEFAULT

  # TODO: Test terminal capabilitie
  #       Bash only supports \u \U since 4.2
  if [[ "${KUBE_PS1_SHELL}" == "bash" ]]; then
    if ((BASH_VERSINFO[0] < 4)); then
      _KUBE_PS1_SYMBOL_DEFAULT=$'\xE2\x8E\x88 '
      _KUBE_PS1_SYMBOL_IMG=$'\xE2\x98\xB8 '
    else
      _KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT}"
      _KUBE_PS1_SYMBOL_IMG=$'\u2638 '
    fi
  elif [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    _KUBE_PS1_SYMBOL_DEFAULT="${KUBE_PS1_SYMBOL_DEFAULT}"
    _KUBE_PS1_SYMBOL_IMG=$'\u2638 '
  else
    _KUBE_PS1_SYMBOL_DEFAULT="k8s"
  fi

  if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_IMG}"
  else
    KUBE_PS1_SYMBOL="${_KUBE_PS1_SYMBOL_DEFAULT}"
  fi
}

_kube_ps1_split() {
  type setopt >/dev/null 2>&1 && setopt SH_WORD_SPLIT
  local IFS=$1
  echo $2
}

_kube_ps1_file_newer_than() {
  local mtime
  local file=$1
  local check_time=$2

  if [[ "${KUBE_PS1_SHELL}" == "zsh" ]]; then
    mtime=$(stat +mtime "${file}")
  elif [ x"$KUBE_PS1_UNAME" = x"Linux" ]; then
    mtime=$(stat -c %Y "${file}")
  else
    mtime=$(stat -f %m "$file")
  fi

  [ "${mtime}" -gt "${check_time}" ]
}

_kube_ps1_update_cache() {
  [[ -n "${KUBE_PS1_TOGGLE}" ]] && return
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && return

  local conf

  if [[ "${KUBECONFIG}" != "${KUBE_PS1_KUBECONFIG_CACHE}" ]]; then
    KUBE_PS1_KUBECONFIG_CACHE=${KUBECONFIG}
    _kube_ps1_get_context_ns
    return
  fi

  # kubectl will read the environment variable $KUBECONFIG
  # otherwise set it to ~/.kube/config
  for conf in $(_kube_ps1_split : "${KUBECONFIG:-$HOME/.kube/config}"); do
    [[ -r "${conf}" ]] || continue
    if _kube_ps1_file_newer_than "${conf}" "${KUBE_PS1_LAST_TIME}"; then
      _kube_ps1_get_context_ns
      return
    fi
  done
}

# TODO: Break this function apart:
#       one for context and one for namespace
_kube_ps1_get_context_ns() {
  # Set the command time
  # TODO: Use a builtin instead of date
  # KUBE_PS1_LAST_TIME=$(printf %t)
  KUBE_PS1_LAST_TIME=$(date +%s)

  if ! _kube_ps1_binary_check "${KUBE_PS1_BINARY}"; then
    KUBE_PS1_CONTEXT="BINARY-N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  fi

  KUBE_PS1_CONTEXT="$(${KUBE_PS1_BINARY} config current-context 2>/dev/null)"
  if [[ -z "${KUBE_PS1_CONTEXT}" ]]; then
    KUBE_PS1_CONTEXT="N/A"
    KUBE_PS1_NAMESPACE="N/A"
    return
  elif [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    KUBE_PS1_NAMESPACE="$(${KUBE_PS1_BINARY} config view --minify --output 'jsonpath={..namespace}' 2>/dev/null)"
    # Set namespace to 'default' if it is not defined
    KUBE_PS1_NAMESPACE="${KUBE_PS1_NAMESPACE:-default}"
  fi
}

# Set shell options
_kube_ps1_shell_settings

# Set colors
_kube_ps1_set_colors

# Set symbol
_kube_ps1_symbol

_kube_toggle_on_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt on

Usage: kubeon [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global  turn on kube-ps1 status globally
  -h --help    print this message
EOF
}

_kube_toggle_off_usage() {
  cat <<"EOF"
Toggle kube-ps1 prompt off

Usage: kubeoff [-g | --global] [-h | --help]

With no arguments, turn off kube-ps1 status for this shell instance (default).

  -g --global turn off kube-ps1 status globally
  -h --help   print this message
EOF
}

kubeon() {
  if [[ "$#" -eq 0 ]]; then
    unset KUBE_PS1_TOGGLE
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kube_toggle_on_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    rm -f "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "${1}" != '-g' && "${1}" != '--global' ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _kube_toggle_on_usage
  else
    _kube_toggle_on_usage
    return
  fi
}

kubeoff() {
  if [[ "$#" -eq 0 ]]; then
    export KUBE_PS1_TOGGLE=off
  elif [[ "${1}" == '-h' || "${1}" == '--help' ]]; then
    _kube_toggle_off_usage
  elif [[ "${1}" == '-g' || "${1}" == '--global' ]]; then
    mkdir -p "$(dirname $KUBE_PS1_DISABLE_PATH)"
    touch "${KUBE_PS1_DISABLE_PATH}"
  elif [[ "${1}" != '-g' && "${1}" != '--global' ]]; then
    echo -e "error: unrecognized flag ${1}\\n"
    _kube_toggle_off_usage
  else
    return
  fi
}

# Build our prompt
kube_ps1() {
  [[ -n "${KUBE_PS1_TOGGLE}" ]] && return
  [[ -f "${KUBE_PS1_DISABLE_PATH}" ]] && return

  local KUBE_PS1

  # Background Color
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="${_KUBE_PS1_BG_COLOR}"

  if [[ -n "${KUBE_PS1_PREFIX}" ]]; then
    KUBE_PS1+="${KUBE_PS1_PREFIX}"
  fi

  if [[ "${KUBE_PS1_SYMBOL_ENABLE}" == true ]]; then
    if [[ "${KUBE_PS1_SYMBOL_USE_IMG}" == true ]]; then
      KUBE_PS1+="${KUBE_PS1_SYMBOL}"
    else
      KUBE_PS1+="${_KUBE_PS1_SYMBOL_COLOR}${KUBE_PS1_SYMBOL}${_KUBE_PS1_RESET_COLOR}"
    fi
    if [[ -n "${KUBE_PS1_SEPARATOR}" ]]; then
      KUBE_PS1+="${KUBE_PS1_SEPARATOR}"
    fi
  fi

  KUBE_PS1+="${_KUBE_PS1_CTX_COLOR}${KUBE_PS1_CONTEXT}${_KUBE_PS1_RESET_COLOR}"

  # Namespace
  if [[ "${KUBE_PS1_NS_ENABLE}" == true ]]; then
    if [[ -n "${KUBE_PS1_DIVIDER}" ]]; then
      KUBE_PS1+="${KUBE_PS1_DIVIDER}"
    fi
    KUBE_PS1+="${_KUBE_PS1_NS_COLOR}${KUBE_PS1_NAMESPACE}${_KUBE_PS1_RESET_COLOR}"
  fi

  # Suffix
  if [[ -n "${KUBE_PS1_SUFFIX}" ]]; then
    KUBE_PS1+="${KUBE_PS1_SUFFIX}"
  fi

  # Close Background color if defined
  [[ -n "${KUBE_PS1_BG_COLOR}" ]] && KUBE_PS1+="${_KUBE_PS1_BG_COLOR_CLOSE}"

  echo "${KUBE_PS1}"
}
