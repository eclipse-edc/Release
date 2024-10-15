#!/bin/bash

set -ve

# release should always happen from a dedicated branch, SOURCE_BRANCH must be set
if [ -z "${SOURCE_BRANCH}" ]; then
  echo "SOURCE_BRANCH variable not set and it is mandatory."
  exit 1;
fi

# VERSION is mandatory
if [ -z "${VERSION}" ]; then
  echo "VERSION variable not set and it is mandatory."
  exit 1;
fi

echo "Will build version '$VERSION' off of branch '$SOURCE_BRANCH'"

# removes any dash, performs toLower
toVersionCatalogName () {
  replacement=""
  input=$1
  cleaned=$(echo "${input//-/"$replacement"}")
  lower=$(echo "$cleaned" | tr '[:upper:]' '[:lower:]')
  echo $lower
}

# the core components
declare -a components=("Runtime-Metamodel" "GradlePlugins" "Connector" "IdentityHub" "FederatedCatalog")

# create the base settings.gradle.kts file containing the version catalogs
cat << EOF > settings.gradle.kts
rootProject.name = "edc"

// this is needed to have access to snapshot builds of plugins
pluginManagement {
    repositories {
        mavenLocal()
        maven {
            url = uri("https://oss.sonatype.org/content/repositories/snapshots/")
        }
        mavenCentral()
        gradlePluginPortal()
    }
}

dependencyResolutionManagement {
    repositories {
        maven {
            url = uri("https://oss.sonatype.org/content/repositories/snapshots/")
        }
        mavenCentral()
        mavenLocal()
    }
    versionCatalogs {
        create("runtimemetamodel"){
          from("org.eclipse.edc:runtime-metamodel-versions:$VERSION")
        }
        create("gradleplugins") {
          from("org.eclipse.edc:edc-versions:$VERSION")
        }
        create("connector") {
          from("org.eclipse.edc:connector-versions:$VERSION")
        }
        create("identityhub") {
          from("org.eclipse.edc:identity-hub-versions:$VERSION")
        }
        create("federatedcatalog") {
          from("org.eclipse.edc:federated-catalog-versions:$VERSION")
        }
    }
}

EOF


# create gradle.properties file for the release
cat << EOF > gradle.properties
group=org.eclipse.edc
version=$VERSION
javaVersion=17
annotationProcessorVersion=$VERSION
edcGradlePluginsVersion=$VERSION
edcDeveloperId=mspiekermann
edcDeveloperName=Markus Spiekermann
edcDeveloperEmail=markus.spiekermann@isst.fraunhofer.de
edcScmConnection=scm:git:git@github.com:eclipse-edc/Connector.git
edcWebsiteUrl=https://github.com/eclipse-edc/Connector.git
edcScmUrl=https://github.com/eclipse-edc/Connector.git
EOF

# clone all the component repositories
for component in "${components[@]}"
do
  rm -rf "$component"
  git clone -b "$SOURCE_BRANCH" "https://github.com/eclipse-edc/$component"
done

# update the project version
sed -i 's#^version=.*#version='"$VERSION"'#g' $(find . -name "gradle.properties")

# update the eventual core library version in the version catalog
sed -i 's#^edc\s*=\s*.*#edc = "'"$VERSION"'"#g' $(find . -name "libs.versions.toml")

# Copy LICENSE and NOTICE.md files to root, to be included in the jar
cp Connector/LICENSE .
cp Connector/NOTICE.md .

# create a comprehensive DEPENDENCIES file on root, to be included in the jar
cat */DEPENDENCIES | sort -u > DEPENDENCIES

# prebuild and publish plugins and modules to local repository, this needed to permit the all-in-one publish later
for component in "${components[@]}"
do
  # publish artifacts to maven local
  echo "Build and publish to maven local component $component"
  cd "$component"
  ./gradlew -Pskip.signing "-Pversion=$VERSION" publishToMavenLocal -Dorg.gradle.internal.network.retry.max.attempts=5 -Dorg.gradle.internal.network.retry.initial.backOff=5000
  cd ..
done

for component in "${components[@]}"
do
  # rename version-catalog module to avoid conflicts
  mv ${component}/version-catalog ${component}/${component}-version-catalog-1
  sed -i "s#:version-catalog#:${component}-version-catalog-1#g" ${component}/settings.gradle.kts

  # copy all the component modules into the main settings, adding the component name in the front of it
  cat $component/settings.gradle.kts | grep "include(" | grep -v "system-tests" | grep -v "launcher" | grep -v "data-plane-integration-tests" | sed "s/\":/\":$component:/g" >> settings.gradle.kts

  # update all the dependency with the new project tree
  sed -i "s#project(\":#project(\":$component:#g" $(find $component -name "build.gradle.kts")

  # update all dependency with the new version catalog prefix
  versionCatalogName=$(toVersionCatalogName $component)
  sed -i "s#(libs\.#(${versionCatalogName}\.#g" $(find $component -name "build.gradle.kts")

  # remove unneeded stuff
  rm -rf $component/system-tests
  rm -rf $component/launcher
  rm -rf $component/launchers
done

# runtime metamodel needs its libs file to get the edc-build version to be used
cp Runtime-Metamodel/gradle/libs.versions.toml gradle
