// build-in-container -- CFEngine packages built in containers on the
// CONTAINER_PACKAGES_* docker hosts.
//
// Jenkins finds this file itself: the CFEngine organization folder scans the
// org for a Jenkinsfile in the repository root and makes a job of every branch
// and every pull request, each running its own copy of this file. Nothing in
// infra defines the job.

// Returns the labels to build. build-scripts/labels.txt decides what a branch
// builds. readTrusted reads it from the revision this job is for, without
// cloning the repo.
def selectedLabels() {
  def sel = readTrusted('build-scripts/labels.txt').readLines()
      .collect { it.trim() }
      .findAll { it.startsWith('PACKAGES_') && it ==~ params.LABEL_FILTER }
  if (!sel) {
    error "LABEL_FILTER '${params.LABEL_FILTER}' matches no label in build-scripts/labels.txt."
  }
  return sel
}

// Returns the architecture of the node a label has to build on.
def archOf(String label) {
  return label.contains('_arm_64') ? 'arm64' : 'amd64'
}

// Return the repos we need to check out.
def reposFor(String project) {
  def repos = ['buildscripts', 'core', 'masterfiles']
  if (project == 'nova') { repos.addAll(['enterprise', 'nova', 'mission-portal']) }
  return repos
}

// The revision to use when a repo's parameter is empty. Normally the branch
// this job is for. In a pull request job buildscripts gets the pull request.
// The other repos get the branch it targets.
//
// BASE_BRANCH wins over the job's branch. pr-pipeline passes it, and its matrix
// jobs build it, so this job has to agree with them.
def defaultRev(String repo) {
  if (env.CHANGE_ID) {
    return repo == 'buildscripts' ? "pull/${env.CHANGE_ID}/merge" : env.CHANGE_TARGET
  }
  if (params.BASE_BRANCH?.trim()) { return params.BASE_BRANCH.trim() }
  return env.BRANCH_NAME ?: 'master'
}

// Accepts the same revision forms as the other jobs. A bare number is a pull
// request, which is what cf-bottom sends. tag:NAME is a tag.
def normalizeRev(String rev) {
  if (rev ==~ /\d+/) { return "pull/${rev}/merge" }
  if (rev.startsWith('tag:')) { return rev.substring(4) }
  return rev
}

// Get the revision to build at from <repo>_REV parameter.
def revFor(String repo) {
  def rev = params[repo.toUpperCase().replaceAll('-', '_') + '_REV']
  return (rev && rev.trim()) ? normalizeRev(rev.trim()) : defaultRev(repo)
}

// Returns the refspec to fetch a repo with. Branch heads are always fetched.
// Pull requests live outside refs/heads. Building one means fetching its ref
// too, or its commit is not in the clone.
def refspecFor(String rev) {
  def heads = '+refs/heads/*:refs/remotes/origin/*'
  if (!(rev ==~ /^(?:refs\/)?pull\/\d+\/(merge|head)$/)) { return heads }
  // pull/1234/merge -> [pull, 1234, merge]
  def parts = rev.replaceAll(/^refs\//, '').split('/')
  return "${heads} +refs/pull/${parts[1]}/${parts[2]}:refs/remotes/origin/pr/${parts[1]}"
}

// Runs one build in the workspace of the node the caller allocated.
//
// Cleans up after the previous build. Checks out each repo at its commit from
// shas. Builds, then archives the packages.
//
// opts holds the build-in-container.py flags that vary per build. The flags
// every build shares are added below.
def containerBuild(String opts, List repos, Map shas, Map revs) {
  // The container hands the directories it writes back to us as it exits, so
  // this only covers a build that never got to exit (e.g. killed).
  sh 'sudo chown -R "$(id -u):$(id -g)" "$WORKSPACE" 2>/dev/null || true'
  cleanWs(deleteDirs: true, notFailBuild: true)

  repos.each { repo ->
    dir("src/${repo}") {
      checkout([$class: 'GitSCM',
                branches: [[name: shas[repo]]],
                userRemoteConfigs: [[url: "git@github.com:cfengine/${repo}.git",
                                     credentialsId: 'jenkins-github',
                                     refspec: refspecFor(revs[repo])]],
                // Full history on purpose: the build reads SOURCE_DATE_EPOCH and
                // every dependency's revision out of git log, so a shallow clone
                // would change the timestamps it pins.
                extensions: [[$class: 'CloneOption', shallow: false, noTags: false, timeout: 30],
                             [$class: 'SubmoduleOption', recursiveSubmodules: true,
                              parentCredentials: true, timeout: 30]]])
    }
  }

  def cacheDir = '/home/jenkins/cfengine-build-cache'
  def buildType = params.RELEASE_BUILD ? 'RELEASE' : 'DEBUG'
  if (params.EXPLICIT_VERSION?.trim()) { opts += " --version '${params.EXPLICIT_VERSION.trim()}'" }

  withCredentials([sshUserPrivateKey(credentialsId: 'jenkins-build-artifacts-cache',
                                     keyFileVariable: 'JENKINS_SFTP_KEY_PATH')]) {
    sh """set -eu
          ./src/buildscripts/build-in-container.py ${opts} \\
              --build-type '${buildType}' \\
              --build-number '${params.PACKAGE_BUILD_NUMBER}' \\
              --source-dir "\$WORKSPACE/src" \\
              --output-dir "\$WORKSPACE/output" \\
              --cache-dir '${cacheDir}' \\
              --sftp-key "\$JENKINS_SFTP_KEY_PATH"
    """
  }

  archiveArtifacts artifacts: 'output/**', fingerprint: true
}

// All filled in by Resolve refs and read by the build stages, which run on other
// nodes. labels holds the build labels asked for. revs and shas hold what was
// asked for, and what it resolved to:
//
//   revs['core'] = pull/1234/merge
//   shas['core'] = 5dca070a98f9be...
//
// Nodes check out the sha, so a push mid-run cannot change what is built. The
// rev is kept too: a sha does not say whether a pull ref has to be fetched.
def shas = [:]
def labels = []
def revs = [:]

pipeline {
  agent none

  options {
    timestamps()
    // Without this, every stage would start by checking out the buildscripts
    // branch this job belongs to, which is not necessarily the revision being
    // built. Each stage checks out the repos it builds itself.
    skipDefaultCheckout(true)
    // The build cache under /home/jenkins is shared by every build on a node,
    // and two runs building the same dependency into it would race.
    disableConcurrentBuilds()
    timeout(time: 8, unit: 'HOURS')
    // Packages are large; keep logs longer than the artifacts.
    buildDiscarder(logRotator(numToKeepStr: '50', artifactNumToKeepStr: '10'))
  }

  parameters {
    // Which of the labels in build-scripts/labels.txt to build. The default
    // builds all of them. A regex, matched against the whole label: hubs only
    // is PACKAGES_HUB_.*, one platform is .*redhat_7, one architecture is
    // .*_arm_64_.*.
    string(name: 'LABEL_FILTER', defaultValue: '.*',
           description: 'Regex matching the build labels to build. See build-scripts/labels.txt.')
    booleanParam(name: 'BUILD_TARBALLS', defaultValue: true,
                 description: 'Build the source tarballs.')

    string(name: 'BASE_BRANCH', defaultValue: '',
           description: 'The branch to build the repos whose revision is empty from.')
    string(name: 'BUILDSCRIPTS_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')
    string(name: 'CORE_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')
    string(name: 'MASTERFILES_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')
    string(name: 'ENTERPRISE_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')
    string(name: 'NOVA_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')
    string(name: 'MISSION_PORTAL_REV', defaultValue: '', description: 'Use NUMBER for a pull request, or pull/NUMBER/merge, or tag:SOME_TAG, or a branch or commit. Leave empty for BASE_BRANCH.')

    choice(name: 'PROJECT', choices: ['nova', 'community'], description: 'CFEngine community or enterprise (nova) edition.')
    booleanParam(name: 'RELEASE_BUILD', defaultValue: false,
                 description: 'Whether BUILD_TYPE should be RELEASE or DEBUG.')
    string(name: 'PACKAGE_BUILD_NUMBER', defaultValue: '1',
           description: 'BUILD_NUMBER for the build, which a DEBUG build puts in the package version.')
    string(name: 'EXPLICIT_VERSION', defaultValue: '',
           description: 'Override the version string the build derives from the sources. Leave empty for the usual behaviour.')
  }

  stages {

    stage('Resolve refs') {
      agent { label 'MASTER_x86_64_linux' }
      steps {
        script {
          labels.addAll(selectedLabels())
          def repos = reposFor(params.PROJECT)
          echo "Building ${labels.size()} labels:\n  ${labels.join('\n  ')}"

          repos.each { repo -> revs[repo] = revFor(repo) }

          // Each platform checks out on its own node, so a push while the job
          // runs would otherwise leave them building different sources. Resolve
          // to commits once, here, and hand those to every build.
          sshagent(['jenkins-github']) {
            repos.each { repo ->
              def rev = revs[repo]
              // "refs/$rev" as well, so pull/<n>/merge resolves like it does in
              // the other jobs. No pipe: it would mask git's own exit status, and
              // an unreachable repo would then look like an unresolvable ref.
              def out = sh(returnStdout: true, script:
                  "git ls-remote git@github.com:cfengine/${repo}.git '${rev}' 'refs/${rev}'").trim()
              def sha = out ? out.readLines()[0].split()[0] : ''
              if (!sha) {
                // A commit id matches no ref, which is the one case where an
                // empty answer is fine.
                if (!(rev ==~ /[0-9a-f]{7,40}/)) { error "${repo}: cannot resolve '${rev}'" }
                sha = rev
              }
              shas[repo] = sha
              echo "${repo}: ${rev} -> ${sha}"
            }
          }

          currentBuild.description = "${params.PROJECT} @ ${shas['core'].take(7)}: ${labels.size()} labels"
        }
      }
    }

    stage('Tarballs') {
      when { expression { return params.BUILD_TARBALLS } }
      agent { label 'CONTAINER_PACKAGES_amd64' }
      steps {
        script {
          // --tarballs builds core and masterfiles alone, in an image of its own,
          // and forces project and platform itself. Only the build type is ours
          // to pass: it decides the version string.
          containerBuild('--tarballs', ['buildscripts', 'core', 'masterfiles'], shas, revs)
        }
      }
    }

    stage('Build') {
      steps {
        script {
          def repos = reposFor(params.PROJECT)

          parallel labels.collectEntries { label ->
            [(label): {
              node("CONTAINER_PACKAGES_${archOf(label)}") {
                // The label decides the platform, the role and the container
                // architecture, so --arch would only contradict it.
                containerBuild("--label '${label}' --project '${params.PROJECT}'",
                               repos, shas, revs)
              }
            }]
          }
        }
      }
    }
  }
}
