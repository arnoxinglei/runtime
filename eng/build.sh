#!/usr/bin/env bash

set -ue

source="${BASH_SOURCE[0]}"

# resolve $source until the file is no longer a symlink
while [[ -h "$source" ]]; do
  scriptroot="$( cd -P "$( dirname "$source" )" && pwd )"
  source="$(readlink "$source")"
  # if $source was a relative symlink, we need to resolve it relative to the path where the
  # symlink file was located
  [[ $source != /* ]] && source="$scriptroot/$source"
done
scriptroot="$( cd -P "$( dirname "$source" )" && pwd )"

usage()
{
  echo "Common settings:"
  echo "  --subset                   Build a subset, print availabe subsets with -subset help"
  echo "  --subsetCategory           Build a subsetCategory, print availabe subsetCategories with -subset help"
  echo "  --os                       Build operating system: Windows_NT or Unix"
  echo "  --arch                     Build platform: x86, x64, arm or arm64"
  echo "  --configuration <value>    Build configuration: Debug or Release (short: -c)"
  echo "  --verbosity <value>        MSBuild verbosity: q[uiet], m[inimal], n[ormal], d[etailed], and diag[nostic] (short: -v)"
  echo "  --binaryLog                Output binary log (short: -bl)"
  echo "  --help                     Print help and exit (short: -h)"
  echo ""

  echo "Actions (defaults to --restore --build):"
  echo "  --restore                  Restore dependencies (short: -r)"
  echo "  --build                    Build all source projects (short: -b)"
  echo "  --buildtests               Build all test projects"
  echo "  --rebuild                  Rebuild all source projects"
  echo "  --test                     Run all unit tests (short: -t)"
  echo "  --pack                     Package build outputs into NuGet packages"
  echo "  --sign                     Sign build outputs"
  echo "  --publish                  Publish artifacts (e.g. symbols)"
  echo "  --clean                    Clean the solution"
  echo ""

  echo "Libraries settings:"
  echo "  --framework                Build framework: netcoreapp or netfx (short: -f)"
  echo "  --coverage                 Collect code coverage when testing"
  echo "  --testscope                Test scope, allowed values: innerloop, outerloop, all"
  echo "  --allconfigurations        Build packages for all build configurations"
  echo ""
  echo "Command line arguments starting with '/p:' are passed through to MSBuild."
  echo "Arguments can also be passed in with a single hyphen."
}

arguments=''
extraargs=''
build=false
buildtests=false
subsetCategory=''
checkedPossibleDirectoryToBuild=false

# Check if an action is passed in
declare -a actions=("r" "restore" "b" "build" "buildtests" "rebuild" "t" "test" "pack" "sign" "publish" "clean")
actInt=($(comm -12 <(printf '%s\n' "${actions[@]/#/-}" | sort) <(printf '%s\n' "${@/#--/-}" | sort)))

while [[ $# > 0 ]]; do
  opt="$(echo "${1/#--/-}" | awk '{print tolower($0)}')"
  case "$opt" in
     -help|-h)
      usage
      exit 0
      ;;
     -subsetcategory)
      subsetCategory="$(echo "$2" | awk '{print tolower($0)}')"
      arguments="$arguments /p:SubsetCategory=$subsetCategory"
      shift 2
      ;;
     -subset)
      arguments="$arguments /p:Subset=$2"
      shift 2
      ;;
     -arch)
      arguments="$arguments /p:ArchGroup=$2 /p:TargetArchitecture=$2"
      shift 2
      ;;
     -configuration|-c)
      val="$(tr '[:lower:]' '[:upper:]' <<< ${2:0:1})${2:1}"
      arguments="$arguments /p:ConfigurationGroup=$val -configuration $val"
      shift 2
      ;;
      # This should be removed after we have finalized our ci build pipeline.
     -framework|-f)
      val="$(echo "$2" | awk '{print tolower($0)}')"
      if [ "$val" == "netcoreapp" ]; then
        val=netcoreapp5.0
      elif [ "$val" == "netfx" ]; then
        val=net472
      fi
      arguments="$arguments /p:TargetGroup=$val"
      shift 2
      ;;
     -os)
      arguments="$arguments /p:OSGroup=$2"
      shift 2
      ;;
     -allconfigurations)
      arguments="$arguments /p:BuildAllConfigurations=true"
      shift 1
      ;;
     -build)
      build=true
      arguments="$arguments -build"
      shift 1
      ;;
     -buildtests)
      buildtests=true
      shift 1
      ;;
     -testscope)
      arguments="$arguments /p:TestScope=$2"
      shift 2
      ;;
     -coverage)
      arguments="$arguments /p:Coverage=true"
      shift 1
      ;;
     -stripsymbols)
      arguments="$arguments /p:BuildNativeStripSymbols=true"
      shift 1
      ;;
      *)
      ea=$1
      
      if [[ $checkedPossibleDirectoryToBuild == false ]] && [[ $subsetCategory == "libraries" ]]; then
        checkedPossibleDirectoryToBuild=true

        if [[ -d "$1" ]]; then
          ea="/p:DirectoryToBuild=$1"
        elif [[ -d "$scriptroot/../src/libraries/$1" ]]; then
          ea="/p:DirectoryToBuild=$scriptroot/../src/libraries/$1"
        fi
      fi

      extraargs="$extraargs $ea"
      shift 1
      ;;
  esac
done

if [[ "$buildtests" == true ]]; then
  if [[ "$build" == true ]]; then
    arguments="$arguments /p:BuildTests=true"
  else
    arguments="$arguments -build /p:BuildTests=only"
  fi
fi

if [ ${#actInt[@]} -eq 0 ]; then
    arguments="-restore -build $arguments"
fi

arguments="$arguments $extraargs"
"$scriptroot/common/build.sh" $arguments
