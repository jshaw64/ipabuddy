#!/bin/bash

APP_LN=/usr/local/bin/ipabuddy
APP_PATH=$(dirname $(readlink $APP_LN))

DEBUG=0
VERBOSE=0

DEF_PLIST_FILE=Info.plist
DEF_BIN_SRC_PATH=${APP_PATH}/in
DEF_BIN_DST_DIR=${APP_PATH}/out

KEY_SHOW_CFBV="show_cfbv"
KEY_SHOW_CFBSV="show_cfbvs"
KEY_SHOW_CFBID="show_cfbid"
KEY_SHOW_ENTITL="show_entitl"
KEY_SHOW_MOBPROV="show_mobprov"
KEY_SHOW_ALL="show_all"
KEY_PLIST_FILE="plist"
KEY_BIN_SRC_PATH="bin_src_path"

E_SRC_FILE=50
E_ENTITLEMENTS=51
E_BINARY=52
E_PAYLOAD=53
E_SIG=54

usage()
{
  cat <<EOF
Usage: ipabuddy [ -b <source bin> | -v <cfbundleversion> | -V <cfbundleshortversion> | -i <cfbundleid> | -e <enitlements> | -p <mobile provision> | -dzh ]
-b  Source Binary
-v  Show CFBundleVersion
-V  Show CFBundleShortVersion
-i  Show CFBundleId
-e  Show Entitlements
-p  Show Mobile Provisioning Profile
-h  Show help
-d  Toggle debug
-z  Toggle verbose
EOF
}

parse_parms()
{
  local bin_src_path="$DEF_BIN_SRC_PATH"
  local show_cfbundleversion=0
  local show_cfbundleshortversion=0
  local show_cfbundleid=0
  local show_entitlements=0
  local show_mobileprovision=0
  local show_all=0

  local OPTIND=1
  while getopts "b:vViepadzh" opt; do
    case "$opt" in
      h )
        usage
        exit 0
        ;;
      d )
        DEBUG=1
        ;;
      z )
        VERBOSE=1
        ;;
      b )
        bin_src_path=${OPTARG}
        ;;
      v )
        show_cfbundleversion=1
        ;;
      V )
        show_cfbundleshortversion=1
        ;;
      i )
        show_cfbundleid=1
        ;;
      e )
        show_entitlements=1
        ;;
      p )
        show_mobileprovision=1
        ;;
      a )
        show_all=1
        ;;
      * )
        usage
        exit
        ;;
    esac
  done

  config_set "$KEY_BIN_SRC_PATH" "$bin_src_path"
  config_set "$KEY_SHOW_CFBV" $show_cfbundleversion
  config_set "$KEY_SHOW_CFBSV" $show_cfbundleshortversion
  config_set "$KEY_SHOW_CFBID" $show_cfbundleid
  config_set "$KEY_SHOW_ENTITL" $show_entitlements
  config_set "$KEY_SHOW_MOBPROV" $show_mobileprovision
  config_set "$KEY_SHOW_ALL" $show_all

  config_set "$KEY_PLIST_FILE" "$DEF_PLIST_FILE"
  config_set "$KEY_BIN_SRC_PATH" "$DEF_BIN_SRC_PATH"
}

inspect_cfbundleversion()
{
  local workspace="$1"

  echo "Inspecting CFBundleShortVersion"

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD
  local plist_src_file=$(config_get "$KEY_PLIST_FILE")
  fs_is_valid_file "$payload_dir_app" "$plist_src_file"
  (( $? > 0 )) && exit $E_PLIST
  local plist_ws_path="${payload_dir_app}/${plist_src_file}"

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist File [$plist_src_file]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist Path [$plist_ws_path]\n"

  local cfbundleversion=$(get_cfbundleversion "$plist_ws_path")
  echo "CFBundleVersion is [$cfbundleversion]"
}

inspect_cfbundleshortversion()
{
  local workspace="$1"

  echo "Inspecting CFBundleVersion..."

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD
  local plist_src_file=$(config_get "$KEY_PLIST_FILE")
  fs_is_valid_file "$payload_dir_app" "$plist_src_file"
  (( $? > 0 )) && exit $E_PLIST
  local plist_ws_path="${payload_dir_app}/${plist_src_file}"

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist File [$plist_src_file]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist Path [$plist_ws_path]\n"

  local cfbundleshortversion=$(get_cfbundleshortversion "$plist_ws_path")
  echo "CFBundleShortVersion is [$cfbundleshortversion]"
}

inspect_cfbundleid()
{
  local workspace="$1"

  echo "Inspecting CFBundleId..."

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD
  local plist_src_file=$(config_get "$KEY_PLIST_FILE")
  fs_is_valid_file "$payload_dir_app" "$plist_src_file"
  (( $? > 0 )) && exit $E_PLIST
  local plist_ws_path="${payload_dir_app}/${plist_src_file}"

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist File [$plist_src_file]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist Path [$plist_ws_path]\n"

  local cfbundleid=$(get_cfbundleid "$plist_ws_path")
  echo "CFBundleId is [$cfbundleid]"
}

inspect_entitlements()
{
  local workspace="$1"

  echo "Inspecting entitlements..."

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"

  local entitlements=$(print_entitlements "$payload_dir_app")
  echo "$entitlements"
}

inspect_mobileprovision()
{
  local workspace="$1"

  echo "Inspecting .mobileprovision..."

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD
  local mobile_prov_file="embedded.mobileprovision"
  local mobile_prov_path="${payload_dir_app}/${mobile_prov_file}"
# why doesn't this work?
#  fs_is_valid_file "$payload_dir_app" "$mobile_prov_path"
#  (( $? > 0 )) && exit $E_MOBILE_PROV

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"

  local mobileprovision=$(print_mobileprovision "$mobile_prov_path")
  echo "$mobileprovision"
}

unpack_binary()
{
  local binary_file_path="$1"
  local workspace="$2"

  echo "Running task: Copy Binary"

  local binary_src_dir=$(fs_parse_path_no_file "$binary_file_path")
  local binary_file=$(fs_parse_file_from_path "$binary_file_path")

  (( DEBUG || VERBOSE )) && printf "\tBinary Source Dir [$binary_src_dir]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary File [$binary_file]\n"
  fs_copy_file "$binary_src_dir" "$workspace" "$binary_file" "$binary_file"

  echo "Running task: Unpack Binary"

  local binary_ws_dir="$workspace"
  local binary_ws_file="$binary_file"
  fs_is_valid_file "$binary_ws_dir" "$binary_ws_file"
  (( $? > 0 )) && exit $E_BINARY
  local binary_ws_path="${workspace}/${binary_ws_file}"

  (( DEBUG || VERBOSE )) && printf "\tBinary Dir: [$binary_ws_dir]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary File: [$binary_ws_file]\n"
  fs_unzip "$binary_ws_dir" "$binary_ws_file" "$workspace"
}

run_tasks()
{
  local workspace="$1"
  local show_all=$(config_get "$KEY_SHOW_ALL")

  if [ $show_all -eq 1 ]; then
    inspect_cfbundleversion "$workspace"
    inspect_cfbundleshortversion "$workspace"
    inspect_cfbundleid "$workspace"
    inspect_entitlements "$workspace"
    inspect_mobileprovision "$workspace"
  else
    local show_cfbundleversion=$(config_get "$KEY_SHOW_CFBV")
    local show_cfbundleshortversion=$(config_get "$KEY_SHOW_CFBSV")
    local show_cfbundleid=$(config_get "$KEY_SHOW_CFBID")
    local show_entitlements=$(config_get "$KEY_SHOW_ENTITL")
    local show_mobileprovision=$(config_get "$KEY_SHOW_MOBPROV")

    if [ $show_cfbundleversion -eq 1 ]; then 
      inspect_cfbundleversion "$workspace"
    fi
    if [ $show_cfbundleshortversion -eq 1 ]; then
      inspect_cfbundleshortversion "$workspace"
    fi
    if [ $show_cfbundleid -eq 1 ]; then
      inspect_cfbundleid "$workspace"
    fi
    if [ $show_entitlements -eq 1 ]; then
      inspect_entitlements "$workspace"
    fi
    if [ $show_mobileprovision -eq 1 ]; then
      inspect_mobileprovision "$workspace"
    fi
  fi
}

main()
{
  . ${APP_PATH}/lib/ipautils/ipautils.sh
  . ${APP_PATH}/lib/config/config.sh
  . ${APP_PATH}/lib/fsutils/fsutils.sh

  parse_parms "$@"

  local bin_src_parm=$(config_get "$KEY_BIN_SRC_PATH")
  local bin_src_path_abs=$(fs_get_abs_path "$bin_src_parm")
  local bin_src_dir_abs=$(fs_parse_path_no_file "$bin_src_path_abs")
  fs_is_valid_dir "$bin_src_dir_abs"
  (( $? > 0 )) && exit $E_BIN_SRC

  local binary_files=()
  local bin_src_file=$(fs_parse_file_from_path "$bin_src_path_abs")
  local bin_src_is_dir=0
  fs_is_valid_file "$bin_src_dir_abs" "$bin_src_file"
  bin_src_is_dir=$(( $? > 0 ? 1 : 0 ))

  if [ $bin_src_is_dir -eq 1 ]; then
    local binary_filter="${bin_src_dir_abs}/*.ipa"
    binary_files=$( fs_get_files_for_filter "$binary_filter" )
  else
    local bin_ext=${bin_src_file##*.}
    if [ "$bin_ext" = "ipa" ]; then
      binary_files=( "$bin_src_path_abs" )
    fi
  fi

  local workspace=$(fs_create_tmp_dir)
  trap "fs_rm_dir $workspace" EXIT

  for binary_file_path in ${binary_files[@]}; do
    echo "Running tasks..."
    (( DEBUG || VERBOSE )) && printf "\tBinary Source Parm [$bin_src_parm]\n"
    (( DEBUG || VERBOSE )) && printf "\tBinary Source Path [$bin_src_path_abs]\n"
    (( DEBUG || VERBOSE )) && printf "\tBinary Source Dir [$bin_src_dir_abs]\n"
    unpack_binary "$binary_file_path" "$workspace"
    run_tasks "$workspace"

  done

  exit 0
}

main "$@"
