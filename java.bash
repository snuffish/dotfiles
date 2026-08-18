#!/bin/bash

# Different java versions
function useJava17() {
  export JAVA_HOME="$HOME/.jdks/jdk-17.0.9"
  alias java="\$JAVA_HOME/bin/java"
}

function useJava8() {
  export JAVA_HOME="$HOME/.jdks/jdk8u392-full"
  alias java="\$JAVA_HOME/bin/java"
}

# Compile with dependencies
alias mvnCompileWithDependencies="mvn clean compile assembly:single"

alias intellij="idea64"
