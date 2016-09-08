#!/bin/bash

APP_LN=/usr/local/bin/ipabuddy
APP_PATH=$(readlink $APP_LN)

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
Usage: resignme [ -p <plist> | -P <prov prof> | -e <entitlements> | -b <bin src> | -B <bin dst> | -t <team id> | -s <sign id> | -a <app id> | -V <version> | -dv ]
-p  Plist (file name)
-P  Provisioning Profile (file path)
-e  Entitlements (file path)
-b  Binary Source (file path or directory)
-B  Binary Destination (directory)
-t  Team ID
-s  Sign ID
-a  App ID
-V  Version
-h  Show help
-d  Toggle debug
-v  Toggle verbose
EOF
}

parse_parms()
{
  local show_cfbundleversion=0
  local show_cfbundleshortversion=0
  local show_cfbundleid=0
  local show_entitlements=0
  local show_mobileprovision=0

  local OPTIND=1
  while getopts "bBiepvdh" opt; do
    case "$opt" in
      h )
        usage
        exit 0
        ;;
      d )
        DEBUG=1
        ;;
      v )
        VERBOSE=1
        ;;
      b )
        show_cfbundleversion=1
        ;;
      B )
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
      * )
        usage
        exit
        ;;
    esac
  done

  config_set "$KEY_SHOW_CFBV" $show_cfbundleversion
  config_set "$KEY_SHOW_CFBSV" $show_cfbundleshortversion
  config_set "$KEY_SHOW_CFBID" $show_cfbundleid
  config_set "$KEY_SHOW_ENTITL" $show_entitlements
  config_set "$KEY_SHOW_MOBPROV" $show_mobileprovision

  config_set "$KEY_PLIST_FILE" "$DEF_PLIST_FILE"
  config_set "$KEY_BIN_SRC_PATH" "$DEF_BIN_SRC_PATH"
}

task_copy_binary_ws()
{
  local binary_src_dir="$1"
  local binary_src_file="$2"
  local binary_dst_dir="$3"
  local binary_dst_file="$binary_src_file"

  fs_copy_file "$binary_src_dir" "$binary_dst_dir" "$binary_src_file" "$binary_dst_file"
  (( $? > 0 )) && exit $E_TASK_COPY_BIN
}

task_unpack_binary()
{
  local unpack_src_dir="$1"
  local unpack_src_file="$2"
  local unpack_dst_dir="$3"

  fs_unzip "$unpack_src_dir" "$unpack_src_file" "$unpack_dst_dir"
  (( $? > 0 )) && exit $E_TASK_UNPACK_BIN
}

task_modify_plist()
{
  local plist_path="$1"
  local app_id="$2"
  local version="$3"

  task_set_cfbundleid "$plist_path" "$app_id"
  task_set_cfbundleversion "$plist_path" "$version"
  task_set_cfbundleshortversion "$plist_path" "$version"
}

task_set_cfbundleid()
{
  local plist_path="$1"
  local app_id="$2"

  if [ -z "$app_id" ]; then
    app_id=$(get_cfbundleid "$plist_path")
  fi

  set_cfbundleid "$app_id" "$plist_path"
}

task_set_cfbundleversion()
{
  local plist_path="$1"
  local version="$2"
  local new_bundle_version="$version"

  if [ -z "$new_bundle_version" ]; then 
    local old_bundle_version=$(get_cfbundleversion "$plist_path")
    new_bundle_version=$(increment "$old_bundle_version")
  fi

  set_cfbundleversion "$new_bundle_version" "$plist_path"
}

task_set_cfbundleshortversion()
{
  local plist_path="$1"
  local version="$2"
  local new_bundle_short_version="$version"

  if [ -z "$new_bundle_short_version" ]; then
    local old_bundle_short_version=$(get_cfbundleshortversion "$plist_path")
    new_bundle_short_version=$(increment "$old_bundle_short_version")
  fi

  set_cfbundleshortversion "$new_bundle_short_version" "$plist_path"
}

task_embed_prov_prof()
{
  local prov_profile_dir="$1"
  local prov_profile_file="$2"
  local payload_dir_app="$3"

  fs_copy_file "$prov_profile_dir" "$payload_dir_app" "$prov_profile_file" "embedded.mobileprovision"
  (( $? > 0 )) && exit $E_TASK_EMBED_PROF
}

task_gen_entitlements()
{
  local entitlements_src_dir="$1"
  local entitlements_src_file="$2"
  local entitlements_dst_dir="$3"
  local entitlements_dst_file="$entitlements_src_file"
  local app_id="$4"
  local team_id="$5"

  prepare_entitlements "$entitlements_src_dir" "$entitlements_dst_dir" "$entitlements_dst_file" "$app_id" "$team_id"
}

task_rm_sig()
{
  local payload_dir_app="$1"
  local sig_dir="$payload_dir_app/_CodeSignature"

  fs_rm_dir "$sig_dir"
  (( $? > 0 )) && exit $E_TASK_RM_SIG
}

task_sign_payload()
{
  local sign_id="$1"
  local payload_dir_app="$2"
  local entitlements_path_ws="$3"

  ipa_sign "$sign_id" "$entitlements_path_ws" "$payload_dir_app"
  (( $? > 0 )) && exit $E_TASK_SIGN_PLOAD
}

task_pack_payload()
{
  local payload_dir_root="$1"
  local payload_dir_name="$2"
  local binary_dir_out="$3"
  local binary_file_out="$4"

  fs_zip_dir "$payload_dir_root" "$payload_dir_name" "$binary_dir_out" "$binary_file_out"
  (( $? > 0 )) && exit $E_TASK_PACK_PLOAD
}

task_clean()
{
  local workspace="$1"

  fs_rm_dir_contents "$workspace"
  (( $? > 0 )) && exit $E_TASK_CLEAN
}

run_tasks()
{
  local binary_file_path="$1"
  local workspace="$2"

  echo "Running task: Copy Binary"

  local binary_src_dir=$(fs_parse_path_no_file "$binary_file_path")
  local binary_file=$(fs_parse_file_from_path "$binary_file_path")

  (( DEBUG || VERBOSE )) && printf "\tBinary Source Dir [$binary_src_dir]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary File [$binary_file]\n"
  task_copy_binary_ws "$binary_src_dir" "$binary_file" "$workspace"

  echo "Running task: Unpack Binary"

  local binary_ws_dir="$workspace"
  local binary_ws_file="$binary_file"
  fs_is_valid_file "$binary_ws_dir" "$binary_ws_file"
  (( $? > 0 )) && exit $E_BINARY
  local binary_ws_path="${workspace}/${binary_ws_file}"

  (( DEBUG || VERBOSE )) && printf "\tBinary Dir: [$binary_ws_dir]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary File: [$binary_ws_file]\n"
  task_unpack_binary "$binary_ws_dir" "$binary_ws_file" "$workspace"

  echo "Running Task: Modify Plist"

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD
  local plist_src_file=$(config_get "$KEY_PLIST_FILE")
  fs_is_valid_file "$payload_dir_app" "$plist_src_file"
  (( $? > 0 )) && exit $E_PLIST
  local plist_ws_path="${payload_dir_app}/${plist_src_file}"
  local app_id=$(config_get "$KEY_APP_ID")
  local version=$(config_get "$KEY_VERSION")

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist File [$plist_src_file]\n"
  (( DEBUG || VERBOSE )) && printf "\tPlist Path [$plist_ws_path]\n"
  (( DEBUG || VERBOSE )) && printf "\tApp ID Parm [$app_id]\n"
  (( DEBUG || VERBOSE )) && printf "\tVersion Parm [$version]\n"
  task_modify_plist "$plist_ws_path" "$app_id" "$version"

  echo "Running task: Embed Provisioning Profile..."

  local prov_prof_parm=$(config_get "$KEY_PROV_PROF_PATH")
  local prov_prof_path_abs=$(fs_get_abs_path "$prov_prof_parm")
  local prov_prof_dir_abs=$(fs_parse_path_no_file "$prov_prof_path_abs")
  fs_is_valid_dir "$prov_prof_dir_abs"
  (( $? > 0 )) && exit $E_PROV_PROF_INIT
  local prov_prof_file=$(fs_parse_file_from_path "$prov_prof_path_abs")
  fs_is_valid_file "$prov_prof_dir_abs" "$prov_prof_file"
  (( $? > 0 )) && exit $E_PROV_PROF

  (( DEBUG || VERBOSE )) && printf "\tProvisioning Profile Parm [$prov_prof_parm]\n"
  (( DEBUG || VERBOSE )) && printf "\tProvisioning Profile Path [$prov_prof_path_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tProvisioning Profile Dir [$prov_prof_dir_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tProvisioning Profile File [$prov_prof_file]\n"
  task_embed_prov_prof "$prov_prof_dir_abs" "$prov_prof_file" "$payload_dir_app"

  echo "Running task: Generate Entitlements"

  local app_id=$(get_cfbundleid "$plist_ws_path")
  local team_id=$(config_get "$KEY_TEAM_ID")
  local entitlements_parm=$(config_get "$KEY_ENTITLEMENTS_PATH")
  local entitlements_path_abs=$(fs_get_abs_path "$entitlements_parm")
  local entitlements_dir_abs=$(fs_parse_path_no_file "$entitlements_path_abs")
  fs_is_valid_dir "$entitlements_dir_abs"
  (( $? > 0 )) && exit $E_ENTITLEMENTS
  local entitlements_file=$(fs_parse_file_from_path "$entitlements_path_abs")
  fs_is_valid_file "$entitlements_dir_abs" "$entitlements_file"
  (( $? > 0 )) && exit $E_ENTITLEMENTS

  (( DEBUG || VERBOSE )) && printf "\tApp ID [$app_id]\n"
  (( DEBUG || VERBOSE )) && printf "\tTeam ID [$team_id]\n"
  (( DEBUG || VERBOSE )) && printf "\tEntitlements Parm [$entitlements_parm]\n"
  (( DEBUG || VERBOSE )) && printf "\tEntitlements Path [$entitlements_path_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tEntitlements Dir [$entitlements_dir_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tEntitlements File [$entitlements_file]\n"
  task_gen_entitlements "$entitlements_dir_abs" "$entitlements_file" "$workspace" "$app_id" "$team_id"

  echo "Running task: Remove Signature"

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"
  task_rm_sig "$payload_dir_app"

  echo "Running task: Sign Payload"

  local sign_id=$(config_get "$KEY_SIGN_ID")
  local entitlements_ws_path="${workspace}/${entitlements_file}"

  (( DEBUG || VERBOSE )) && printf "\tSign ID [$sign_id]\n"
  (( DEBUG || VERBOSE )) && printf "\tEntitlements Path [$entitlements_ws_path]\n"
  task_sign_payload "$sign_id" "$payload_dir_app" "$entitlements_ws_path" 

  echo "Running task: Pack Payload"

  local payload_dir_name="Payload"
  local version=$(get_cfbundleversion "$plist_ws_path")
  local bin_dst_parm=$(config_get "$KEY_BIN_DST_DIR")
  local bin_dst_path_abs=$(fs_get_abs_path "$bin_dst_parm")
  local bin_dst_dir_abs=$(fs_parse_path_no_file "$bin_dst_path_abs")
  fs_is_valid_dir "$bin_dst_dir_abs"
  (( $? > 0 )) && exit $E_BIN_DST
  local binary_file_no_dir="$binary_file"
  local binary_file_out_pref="${binary_file_no_dir%.*}"
  local binary_file_out_suff="${version}"
  local binary_file_out="${binary_file_out_pref}_${binary_file_out_suff}.ipa"

  (( DEBUG || VERBOSE )) && printf "\tBinary Dest Parm [$bin_dst_parm]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary Dest Path [$bin_dst_path_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary Dest Dir [$bin_dst_dir_abs]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary Dest File [$binary_file_out]\n"
  task_pack_payload "$workspace" "$payload_dir_name" "$bin_dst_dir_abs" "$binary_file_out"

  task_clean "$workspace"

  (( DEBUG )) && open "$workspace"
}

inspect_cfbundleversion()
{
  local workspace="$1"

  echo "Running Task: Modify Plist"

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

  echo "Running Task: Modify Plist"

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

  echo "Running Task: Modify Plist"

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

  echo "Running Task: Modify Plist"

  local payload_dir_app=$(fs_get_files_for_filter "${workspace}/Payload/*")
  fs_is_valid_dir "$payload_dir_app"
  (( $? > 0 )) && exit $E_PAYLOAD

  (( DEBUG || VERBOSE )) && printf "\tPayload App Dir [$payload_dir_app]\n"

  local entitlements=$(print_entitlements "$payload_dir_app")
  echo "$entitlements"
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
  task_copy_binary_ws "$binary_src_dir" "$binary_file" "$workspace"

  echo "Running task: Unpack Binary"

  local binary_ws_dir="$workspace"
  local binary_ws_file="$binary_file"
  fs_is_valid_file "$binary_ws_dir" "$binary_ws_file"
  (( $? > 0 )) && exit $E_BINARY
  local binary_ws_path="${workspace}/${binary_ws_file}"

  (( DEBUG || VERBOSE )) && printf "\tBinary Dir: [$binary_ws_dir]\n"
  (( DEBUG || VERBOSE )) && printf "\tBinary File: [$binary_ws_file]\n"
  task_unpack_binary "$binary_ws_dir" "$binary_ws_file" "$workspace"
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
    inspect_cfbundleversion "$workspace"
    inspect_cfbundleshortversion "$workspace"
    inspect_cfbundleid "$workspace"
    inspect_entitlements "$workspace"

  done

  open "$workspace"

  exit 0
}

main "$@"
