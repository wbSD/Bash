#!/bin/bash
#-------------------------------------------------------------
# Version
#-------------------------------------------------------------
version=24

#-------------------------------------------------------------
# Default settings. Saved after an update
#-------------------------------------------------------------
startUpFolder=/c/Work/WebVersion
autoUpdate=true
betaUpdate=false
myGitUser=
buddyGitUser=
buddyBranch="BuddyBranch"
fixGitPromptShowBranch=true

#-------------------------------------------------------------
# Aliases
#-------------------------------------------------------------
alias status="git status"
alias log="git log --graph --pretty=format:'%Cred%h%Creset -%C(yellow)%d%Creset %s %Cgreen(%cr) %C(bold cyan)<%an>%Creset' --abbrev-commit"

#-------------------------------------------------------------
# Variables
#-------------------------------------------------------------
workFolders=( "WorkBook.UI" "WorkBook.Client" "WorkBook.Server" )
tmpnewfile=~/.bashrctmp
declare -a cherryPickCommits
declare lastCherryPickBranch

cd $startUpFolder 

#-------------------------------------------------------------
# Functions
#-------------------------------------------------------------

function sync {
  git fetch upstream
  if [ $? == 1 ]
  then
    echo "Fetch failed"
    return;
  fi
  git rebase upstream/$(getCurrentBranch)
  sup
}

function sup {
  git submodule update --init --recursive
}
 
function cleantemp {
  for i in "${workFolders[@]}"
  do
    if [ -d $i"/bin" ]; then
     rm -rf $i"/bin"
  fi
      if [ -d $i"/obj" ]; then
     rm -rf $i"/obj"
  fi  
  done
}
 
function cleanbranches {
  echo "This will remove all merged branches that are linked to the current upstream branch"
  git branch --merged
  echo "Sure you want to remove all unmerged local branches ? [YES]/[NO]"
  read continue
  if [ $continue == 'YES' ]
    then
      git branch --merged | grep -v "\*" | xargs -n 1 git branch -d
      git branch --merged | grep -v "\*" | xargs -n 1 git push origin :{}
    else
      echo "Aborting"
  fi
}
 function xxx {
   local stuff=$(git branch --r | grep "origin" | tr -d 'origin/')
   echo $stuff
 }
 
function reset {  
  if [[ -n "$1" ]]; then
    git reset --soft HEAD~$1
    else
    git reset --soft HEAD@{1}
   fi
   git reset .   
} 
 
function ch {
  local doCleanup=true  

   git checkout $1
   if [ $? != 0 ]
   then
   echo "ERROR! Could not check out branch $1"
     return 1
   fi      

  sup
  if [ "$2" == "--nc" ]
    then
    doCleanup=false
  fi
  
  if [ $doCleanup == true ]
  then
  echo "Doing Cleanupz"
   cleantemp
  fi
}
  
function pull {
  if ! [ -z "$1" ] 
  then
    git pull origin $1
  else
    git pull origin $(getCurrentBranch)
  fi
}
 
function push {
  git push origin $(getCurrentBranch) $1
}
 
function getCurrentBranch {
  local branch_name=$(git symbolic-ref -q HEAD) 
  branch_name=${branch_name##refs/heads/}
  branch_name=${branch_name:-HEAD}
  echo "$branch_name"
}
 
function search {
  if [ $# == 1 ] || [[ $1 == --* ]]
  then
    git log --stat --pretty --grep=$1
  else
  git log --stat --pretty $@
 fi
}

function cpm {
   if ! [ -z "$1" ] 
   then
      local branch=$1    
    else
      echo -n "branch : "
      read branch
  fi
  
  if [ $1 = '--continue' ];   
  then
      for (( index=${#cherryPickCommits[@]}-1 ; index>=0 ; index-- )) ; do                
        cpm $lastCherryPickBranch ${cherryPickCommits[$index]}                    
        if [ $? == 1 ] 
        then
           echo "Error in Cherry-pick. Please fix and type : cpm --continue"
           unset cherryPickCommits[$index]
           return 1
        fi
        unset cherryPickCommits[$index]      
      done        
      return 0;      
  fi
  
  local user=$(git config user.name)
    
  if ! [ -z "$2" ] 
  then      
    if [ ${#2} -lt 3 ] && [[ $2 != *[!0-9]* ]]; 
    then  
        local commit=$(git log $branch --committer="$user" --pretty=format:%H | sed -n $2p)
    elif [ $2 = 'l' ] 
    then                      
       git log $branch --committer="$user" --oneline -20 |  awk '{printf("%02d %s\n", NR, $0)}'            
       cpm $1
       return 0;
    elif [ $2 = 'b' ]
    then
      IFS=$'\r\n'
      cherryPickCommits=($(git log $(getCurrentBranch)..$branch --pretty=format:%H))
      lastCherryPickBranch=$branch
      unset IFS        
      cpm --continue
      return 0;
      else
        local commit=$2
    fi
    else
         echo -n "commit number, hash, b for complete branch or 'l' for a list : "
         read commit
         if [ $commit == 'q' ]
         then
           echo "Exitting"
           return
         fi
         cpm $branch $commit
         return 1;
  fi
       
  if ! [ -z "$commit" -o -z "$branch" ] 
  then
    local orgBranch=$(getCurrentBranch)
    if [[ $orgBranch != CherryPick* ]]
    then
      git checkout -b "CherryPick_"$(getCurrentBranch)"_"$commit
    fi     
    git cherry-pick -x $commit
    if [ $? == 1 ]     
    then   
      local diff=$(git diff)
      if [ ${#diff} == 0 ]
      then      
        if [[ $orgBranch != CherryPick* ]]
        then    
          git checkout $orgBranch
          git branch -D "CherryPick_"$(getCurrentBranch)"_"$commit
        fi        
       echo "Cherry went wrong, possible empty commit"
       fi
       return 1            
     fi 
  else
    echo "Something went wrong"
  fi      
}

function r1 () {
git cherry-pick --abort
git checkout master
git branch -D CherryPick_master_69c99086a9802092760ef76376794bb3d42c2bf3
}


function request () {
  local repo=`git remote -v | grep ^origin.*\(push\)$ | head -n 1 | sed -e "s/.*github.com[:/]\(.*\)\.git.*/\1/"`
  local branch=$(getCurrentBranch);
  local targetbranch=""

  
  if [[ $branch = CherryPick* ]]; then
    targetbranch=$(echo $branch| cut -d'_' -f 2)	  
  fi
  echo "... creating pull request for branch \"$branch\" in \"$repo\" to target branch \"$targetbranch\" "    
  
  if [[ $targetbranch = master || $targetbranch = "" ]]; then  
        targetbranch=""        
     else
       local upstreamBranch=$(git remote -v | grep '(push)' | grep 'upstream')
       upstreamBranch=$(expr "$upstreamBranch" : '.*\(:.[^\/]*\)')
       upstreamBranch=${upstreamBranch#:}
  
       if [ ${#upstreamBranch} -gt 0 ] 
          then
            targetbranch="$upstreamBranch:$targetbranch..."
            else
            targetbranch="$targetbranch..."
          fi                    
    fi
   
  explorer https://github.com/$repo/pull/new/"$targetbranch$branch"
}

function updateScript() {
  echo "Starting update..."
  # Check that the script is there. If not, load it.
  if [ ! -f $tmpnewfile ]; then   
          getScript          
          if [ $? -eq 0 ]; then          
          echo "No script file found"
          return 0
          fi
  fi  
  checkScriptVersion
  if [ $? -gt 0 ]; then
       echo "Saving old Variables"
       #Save old stuff
       local tmpStartupFolder=$(grep startUpFolder= $tmpnewfile | head -1 | cut -d "=" -f2)
       sed -i.bak "s|startUpFolder=$tmpStartupFolder|startUpFolder=$startUpFolder|g" $tmpnewfile 
      
      local tmpautoUpdate=$(grep autoUpdate= $tmpnewfile | head -1 | cut -d "=" -f2)
      sed -i.bak "s|autoUpdate=$tmpautoUpdate|autoUpdate=$autoUpdate|g" $tmpnewfile
            
      local tmpbetaUpdate=$(grep betaUpdate= $tmpnewfile | head -1 | cut -d "=" -f2)
      sed -i.bak "s|betaUpdate=$tmpbetaUpdate|betaUpdate=$betaUpdate|g" $tmpnewfile
      
      echo "Updating Scripts"
      if [ -f ~/.bash_profile ]; then
	mv ~/.bash_profile ~/.bash_profilebak   
        mv $tmpnewfile ~/.bash_profile    
        source ~/.bash_profile
      else
	mv ~/.bashrc ~/.bashrcbak 
        mv $tmpnewfile ~/.bashrc    
        source ~/.bashrc
      fi

      echo "Bash Script updated"               
  else
      echo "No need to update script, exitting"
      rm -rf $tmpnewfile >> /dev/null
  fi  
}


function checkScriptVersion() {
# Check that the script is there. If not, load it.
  if [ ! -f $tmpnewfile ]; then   
          getScript     
          if [ $? -eq 0 ]; then          
          echo "No script file found"
          return 0
          fi
  fi
  
  #get the version of the just gotten file.
  local newVersion=$(grep version= $tmpnewfile | head -1 | cut -d "=" -f2)

  echo "Checking version. $version -> $newVersion"
   if [ ! -z  "$newVersion" ] && [ $newVersion -gt $version ]; then
   if $betaUpdate || (! $betaUpdate && [ $(( $newVersion % 2 )) -eq 1 ]); then      
         return $newVersion;
    fi        
  fi   
    return 0;
}

function getScript() {    
    echo "Getting Script"
    if [ ! -f $tmpnewfile ]; then
      rm -rf $tmpnewfile >> /dev/null
    fi

      echo "Getting script from dljs Git"
      curl -s -o $tmpnewfile https://raw.githubusercontent.com/dlj/Bash/master/.bash_profile?rand=$RANDOM
  
  if [ ! -f $tmpnewfile ]; then
      echo "No update file found, exitting";
      return 0
  fi
  echo "Script gotten, all is fine"
  return 1
}

#command echos


#functions
function buddy () {
  if [ -z "$buddyBranch" ] || [ $buddyBranch = '' ];
  then
    echo "You need to configure your buddy branch variable (buddyBranch)!"
    return 0
  fi
  
  if [ -z "$myGitUser" ] || [ $myGitUser = '' ];
  then
    echo "You need to configure your github user variable (myGitUser)!"
    return 0
  fi
  
  if [ -z "$buddyGitUser" ] || [ $buddyGitUser = '' ];
  then
    echo "You need to configure your buddy github user variable (buddyGitUser)!"
    return 0
  fi
  
  local repo=`git remote -v | grep push | head -n 1 | sed -e "s/.*github.com[:/]\(.*\)\.git.*/\1/"`
  local branch=$(getCurrentBranch);
  local targetbranch=$buddyBranch
  local targetrepo="${repo/$myGitUser/$buddyGitUser}"
  
  if ! [ -z "$1" ] && [[ $1 != *[!0-9]* ]];
  then
    targetbranch=$buddyBranch$1
  fi
  
  echo "... creating pull request for branch \"$branch\" in \"$repo\" to buddy repo \"$targetrepo\" target branch \"$targetbranch\" "    
  
  targetbranch="$targetbranch..."
  branch="$myGitUser:$branch"

  explorer https://github.com/$targetrepo/pull/new/"$targetbranch$branch"
}

function resetbuddy () {
  if [ -z "$buddyBranch" ] || [ $buddyBranch = '' ];
  then
    echo "You need to configure your buddy branch variable (buddyBranch)!"
    return 0
  fi

  ch master
  sync
  
  local targetBranch=$buddyBranch
  
  if ! [ -z "$1" ] && [[ $1 != *[!0-9]* ]];
  then
    targetBranch=$buddyBranch$1
  fi
  
  if ! [ -z "$1" ] && [ $1 = 'all' ];
  then
    echo "This will wipe $buddyBranch 1 - 10 in your fork, are you sure you wish to continue? [YES]/[NO]"
    echo "Note: This will also remove any open pull requests to the branches"
    read continue
    if [ $continue == 'YES' ] 
    then
      for (( index=1 ; index<=10 ; index++ )) ; do
        git checkout -B $buddyBranch$index
        if [ $? != 0 ]
        then
		  echo "ERROR! Could not check out branch $buddyBranch$index"
          return 1
        fi
        git push origin $buddyBranch$index -f
        if [ $? != 0 ]
        then
		  echo "ERROR! Could not force pushe branch $buddyBranch$index"
          return 1
        fi
		echo "Successfully reset branch $buddyBranch$index"
        ch master
      done
	  echo "Branches $buddyBranch 1 - 10 reset"
    fi
  else
    echo "This will wipe $targetBranch in your fork, are you sure you wish to continue? [YES]/[NO]"
    echo "Note: This will also remove any open pull requests to the branch"
    read continue
    if [ $continue == 'YES' ] 
    then
      git checkout -B $targetBranch
      if [ $? != 0 ]
      then
	    echo "ERROR! Could not check out branch $targetBranch"
        return 1
      fi
      git push origin $targetBranch -f
      if [ $? != 0 ]
      then
	    echo "ERROR! Could not force push branch $targetBranch"
        return 1
      fi
	  echo "Successfully reset branch $targetBranch"
      ch master
    fi
  fi
}

function chb () {
  local targetBranch=$buddyBranch
  
  if ! [ -z "$1" ] && [[ $1 != *[!0-9]* ]];
  then
    targetBranch=$buddyBranch$1
  fi
  
  ch $targetBranch
}

function fixGitPrompt () {
	echo "Fixing weirdness so git bash shows the current branch name"
	update_PS1 () {
	  PS1="\[\033]0;$TITLEPREFIX:${PWD//[^[:ascii:]]/?}\007\]\n\[\033[32m\]\u@\h \[\033[35m\]$MSYSTEM \[\033[33m\]\w\[\033[36m\]`__git_ps1`\[\033[0m\]\n$ "
	}
	shopt -u promptvars
	PROMPT_COMMAND=update_PS1
	echo ""
}

#-------------------------------------------------------------
# Commands
#-------------------------------------------------------------

function commands {
  echo "The following commands are available"
  echo "------------------------------------"
  echo "cleanbranches : Cleans up all merged branches from your local Git"
  echo "cleantemp : Cleans bin and obj folders"
  echo "cpm : Cherry pick. cpm {from} {option}. e.g cpm 8.3.1 l"
  echo "reset : Resets a local commit"
  echo "request : Create a pull request on GitHub"    
  echo "sup : Updates and init submodules on current branch" 
  echo "sync : Synchronize upstream with local git. Remember to push after."
  echo "buddy : Creates a pull request from current branch to your buddy's buddybranch."
  echo "	Optional parameter, e.g. buddy 5 - creates pull request for buddybranch5"
  echo "resetbuddy : Resets your own buddybranch to the current upstream/master revision."
  echo "	THIS DELETES ALL COMMITS/PULL REQUESTS ON THE BRANCH(ES)!"
  echo "	Optional parameter, e.g. resetbuddy 5 (resets your buddybranch5), resetbuddy all (resets branches 1-10)"
}

#-------------------------------------------------------------
#Startup Scripts
#-------------------------------------------------------------
echo "Hello. Super magical DLJ Script"

echo "Beginning"

if $autoUpdate; then
  updateScript;
fi
echo ""
echo "Running user custom scripts, if the file ~/.userscripts exists"
# Load the users custom scripts
if [ -f ~/.userscripts ]; then
  source ~/.userscripts
fi
echo ""
if $fixGitPromptShowBranch; then
	fixGitPrompt;
fi
echo "Type commands for commands that are available"
