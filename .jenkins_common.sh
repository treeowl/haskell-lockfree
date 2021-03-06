
set -e
set -x

if [ "$JENKINS_GHC" == "" ]; then
  echo "Must set JENKINS_GHC to, e.g. '7.6.3', to run this script."
  exit 1
fi

# if [ "$CABAL" == "" ]; then
#   if [ "$GHC" == "ghc-7.10.1" ]; then
#       CABAL=cabal-1.22
       DISABLE_EXEC_PROF="--disable-profiling"
       ENABLE_EXEC_PROF="--enable-profiling"
#   else
#       CABAL=cabal-1.20
#       DISABLE_EXEC_PROF="--disable-executable-profiling"
#       ENABLE_EXEC_PROF="--enable-executable-profiling"
#   fi
# fi

# Temp: trying this [2015.05.04]:
CABAL=cabal-1.22

# IU-specific environment setup.
source $HOME/rn_jenkins_scripts/acquire_ghc.sh
which $CABAL
which -a ghc
which -a ghc-$JENKINS_GHC
$CABAL --version

which -a llc || echo "No LLVM"


# Pass OPTLVL directly to cabal:
CBLARGS=" $OPTLVL "

if [ "$PROF" == "prof" ]; then
  CBLARGS="$CBLARGS --enable-library-profiling $ENABLE_EXEC_PROF"
else
  CBLARGS="$CBLARGS --disable-library-profiling $DISABLE_EXEC_PROF"
fi

if [ "$HPC" == "hpc" ]; then
  # Remove obsolete --enable-library-coverage:
  CBLARGS="$CBLARGS --enable-coverage"
else
  CBLARGS="$CBLARGS --disable-coverage"
fi

if [ "$THREADING" == "nothreads" ]; then
  echo "Compiling without threading support."
  CBLARGS="$CBLARGS -f-threaded "
else
  CBLARGS="$CBLARGS -fthreaded --ghc-options=-threaded "
fi

ALLPKGS="$PKGS $NOTEST_PKGS"

$CABAL sandbox init

root=`pwd`
for subdir in $ALLPKGS; do
  cd "$root/$subdir"
  $CABAL sandbox init --sandbox=$root/.cabal-sandbox
done
cd "$root"

# TODO: This should really be set dynamically.
CBLPAR="-j8"

GHC=ghc-$JENKINS_GHC

# First install everything without testing:
CMDROOT="$CABAL install --reinstall --force-reinstalls $CBLPAR"

# ------------------------------------------------------------
# Method 1: Separate compile and then test.
# Problem is, this is triggering what looks like a cabal-1.20 bug:
#   ++ cabal-1.20 test --show-details=always
#   cabal-1.20: dist/setup-config: invalid argument
# ------------------------------------------------------------

# Install the DEPENDENCIES for packages and tests:
# And install the packages themselves to satisy interdependencies.
$CMDROOT $CBLARGS --enable-tests $PKGS

# List what we've got:
$CABAL sandbox hc-pkg list

echo "Everything installed, now to test."
for subdir in $TESTPKGS; do
  cd "$root/$subdir"
  $CABAL configure --enable-tests $CBLARGS
  # Print the individual test outputs:
  $CABAL test --show-details=streaming
done

# ------------------------------------------------------------
# Method 2: A single install/test command
# ------------------------------------------------------------

# $CMDROOT $CBLARGS $PKGS --run-tests
# $CABAL sandbox hc-pkg list
