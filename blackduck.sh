#!/bin/bash
# Description: blackduck.sh
# Performs software composition scan using Blackduck detect tool for multiple project types (npm, maven, android, ios).

set -e

export DETECT_LATEST_RELEASE_VERSION=7.1.0

function validateOptions() {
  info "Validating program options"

  require "projectType" "${projectType}"
  require "projectName" "${projectName}"

  if [ ! "npm" == "${projectType}" ] && [ ! "maven" == "${projectType}" ] && [ ! "ios" == "${projectType}" ] && [ ! "android" == "${projectType}" ]; then
    error "Unsupported project type. Valid options: [npm, maven, ios, android]."
  fi

  if [ ! -e ${sourcePath} ]; then
    error "Invalid source path provided: ${sourcePath}."
  fi

  if [ ! -z "${detectCodeLocationClassifier}" ]; then
    detectCodeLocationClassifier="-${detectCodeLocationClassifier}"
  fi

  if [ -z "${detectProjectVersionPhase}" ]; then
    if [ "latest" == "${version}" ]; then
      detectProjectVersionPhase='DEVELOPMENT'
    else
      detectProjectVersionPhase='PRERELEASE'
    fi
  fi
}

function performScaScan() {
  info "Proceeding with Blackduck scan"

  local options="--blackduck.url=${hubURL}"
  options="${options} --blackduck.api.token=${hubToken}"
  options="${options} --logging.level.com.synopsys.integration=${logLevel}"
  options="${options} --detect.project.name=${projectName}"
  options="${options} --detect.project.version.name=${version}"
  options="${options} --detect.project.version.phase=${detectProjectVersionPhase}"
  options="${options} --detect.project.version.update=true"

  # shellcheck disable=SC2089
  options="${options} --detect.source.path=\"${sourcePath}\""
  options="${options} --detect.code.location.name=${projectName}-${version}${detectCodeLocationClassifier}"
  options="${options} --detect.detector.search.depth=${detectSearchDepth}"
  options="${options} --detect.excluded.directories.defaults.disabled=true"

  case "${projectType}" in
  maven)
    options="${options} --detect.tools=DETECTOR"
    options="${options} --detect.included.detector.types=MAVEN"
    options="${options} --detect.maven.excluded.scopes=${detectMavenExcludedScopes}"

    local detectMavenBuildCommand=""
    if [ ! -z "${detectMavenProjects}" ]; then
      detectMavenBuildCommand="-pl ${detectMavenProjects}"
    fi

    if [ ! -z "${detectMavenProfiles}" ]; then
      detectMavenBuildCommand="${detectMavenBuildCommand} -P${detectMavenProfiles}"
    fi

    if [ ! -z "${detectMavenBuildCommand}" ]; then
      options="${options} --detect.maven.build.command='${detectMavenBuildCommand}'"
    fi

    ;;
  npm)
    if [ ${enableSignatureScan} == 1 ]; then
      options="${options} --detect.tools=DETECTOR,SIGNATURE_SCAN"
      options="${options} --detect.excluded.directories=${detectExcludedDirectories}"
    else
      options="${options} --detect.tools=DETECTOR"
    fi
    options="${options} --detect.excluded.detector.types='GIT,MAVEN'"
    options="${options} --detect.npm.include.dev.dependencies=false"
    ;;
  ios)
    options="${options} --detect.tools=DETECTOR"
    options="${options} --detect.included.detector.types=cocoapods"
    ;;
  android)
    options="${options} --detect.tools=DETECTOR"
    options="${options} --detect.included.detector.types=gradle"

    if [ "${detectGradleProject}" ]; then
      options="${options} --detect.gradle.included.projects=${detectGradleProject}"
    fi

    if [ "${detectGradleConfiguration}" ]; then
      options="${options} --detect.gradle.included.configurations=${detectGradleConfiguration}"
    fi
    ;;
  *)
    error "Unsupported project type: ${projectType}"
    ;;
  esac

  # shellcheck disable=SC2090
  bash <(curl -s -L https://detect.synopsys.com/detect.sh) ${options}
}

function printHelp() {
  cat <<-EOF
    Usage: $(basename "$0") [ARGS]

    Arguments:
    [--help]
    [--projectType] (required) maven, npm, ios or android.
    [--projectName] (required) project name to be used in Blackduck.
    [--version] Version label of the current build. Default: latest.
    [--sourcePath] Root path where the scanned artifact is built (e.g. directory where the pom.xml aggregating final artifact dependencies lives in). Default: '.'.
    [--logLevel] Log level for Blackduck detect execution. Default: INFO.
    [--detectSearchDepth] Search depth where detector will look for package manager files (i.e. pom.xml) from 'sourcePath' location. Default: 0.
    [--detectProjectVersionPhase] If 'version' option is set to 'latest', phase will be DEVELOPMENT. Otherwise PRERELEASE, if not overridden by this option.
    [--detectCodeLocationClassifier] Append a classifier value to detect.code.location.name property. This is to be used in situations where two or more scan runs need to be mapped to the same scan version.
    [--detectMavenExcludedScopes] Default: test
    [--detectMavenProfiles] If target deliverable is built using additional maven profiles please use this option and inform those. Comma separated, no spaces.
    [--detectMavenProjects] Comma separated list of maven projects to be considered in dependency:tree. Can also be used for exclusion (prefixed with \!). E.g. same as '-pl' maven option.
    [--detectGradleProject] Use this option to filter to a specific gradle project.
    [--detectGradleConfiguration] Default: releaseRuntimeClasspath.
    [--enableSignatureScan] Only valid for npm project type. If enabled, Blackduck signature scan will be conduct. This is not recommended. Package management scans are best advised for optimal component identification.
    [--detectExcludedDirectories] Only valid for npm project type, the paths which should not be scanned. by the signature scanner. Default: '/collections/,/portals/'.
    [--fail] By default, for abnormal execution or validation failures, this script will exit with status 0, printing errors to stdout, but preserving execution of wrapping program (e.g. your pipeline). Set this option to enforce status 1, for abnormal flows.
	EOF
  exit 0
}

#####################################################
# For any given parameter/value combination
# return the value for the parameter, if present.
#####################################################
function parseOption() {
  if [ -n "${2}" ] && [ ${2:0:1} != "-" ]; then
    echo "${2}"
    return
  fi
  error "Missing parameter value for argument $1"
}

function require() { if [ -z "$2" ]; then error "Missing required value for '$1'"; fi; }
function error() {
  echo "ERROR: $1" >&2
  exit ${defaultErrorExitStatus}
}
function warn() { echo "WARN: $1" >&2; }
function info() { echo "INFO: $1" >&2; }

if [ "--help" == "$1" ]; then
  printHelp
fi

# Parse arguments
while (("$#")); do
  case "$1" in
  --fail)
    defaultErrorExitStatus=1
    shift 1
    ;;
  --enableSignatureScan)
    enableSignatureScan=1
    shift 1
    ;;
  --projectType)
    projectType=$(parseOption $1 $2)
    shift 2
    ;;
  --projectName)
    projectName=$(parseOption $1 $2)
    shift 2
    ;;
  --version)
    version=$(parseOption $1 $2)
    shift 2
    ;;
  --sourcePath)
    sourcePath=$(parseOption $1 $2)
    shift 2
    ;;
  --logLevel)
    logLevel=$(parseOption $1 $2)
    shift 2
    ;;
  --detectSearchDepth)
    detectSearchDepth=$(parseOption $1 $2)
    shift 2
    ;;
  --detectProjectVersionPhase)
    detectProjectVersionPhase=$(parseOption $1 $2)
    shift 2
    ;;
  --detectMavenExcludedScopes)
    detectMavenExcludedScopes=$(parseOption $1 $2)
    shift 2
    ;;
  --detectMavenProjects)
    detectMavenProjects=$(parseOption $1 $2)
    shift 2
    ;;
  --detectMavenProfiles)
    detectMavenProfiles=$(parseOption $1 $2)
    shift 2
    ;;
  --detectGradleProject)
    detectGradleProject=$(parseOption $1 $2)
    shift 2
    ;;
  --detectGradleConfiguration)
    detectGradleConfiguration=$(parseOption $1 $2)
    shift 2
    ;;
  --detectExcludedDirectories)
    detectExcludedDirectories=$(parseOption $1 $2)
    shift 2
    ;;
  --detectCodeLocationClassifier)
    detectCodeLocationClassifier=$(parseOption $1 $2)
    shift 2
    ;;
  *) error "Unsupported option $1" ;;
  esac
done

validateOptions
performScaScan

exit 0
