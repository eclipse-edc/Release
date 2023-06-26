#!/bin/bash

set -ve

# removes any dash, performs toLower
toVersionCatalogName () {
  replacement=""
  input=$1
  cleaned=$(echo "${input//-/"$replacement"}")
  lower=$(echo "$cleaned" | tr '[:upper:]' '[:lower:]')
  echo $lower
}

# the components that need to be built
declare -a components=("Runtime-Metamodel" "GradlePlugins" "Connector" "IdentityHub" "RegistrationService" "FederatedCatalog" "Technology-Azure" "Technology-Aws" "Technology-Gcp")

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
        create("gradleplugins") {
          from("org.eclipse.edc:edc-versions:$VERSION")
        }
        create("connector") {
          from("org.eclipse.edc:connector-versions:$VERSION")
        }
        create("identityhub") {
          from("org.eclipse.edc:identity-hub-versions:$VERSION")
        }
        create("registrationservice") {
          from("org.eclipse.edc:registration-service-versions:$VERSION")
        }
        create("federatedcatalog") {
          from("org.eclipse.edc:federated-catalog-versions:$VERSION")
        }
        create("technologyazure") {
          from("org.eclipse.edc:technology-azure-versions:$VERSION")
        }
        create("technologyaws") {
          from("org.eclipse.edc:technology-aws-versions:$VERSION")
        }
        create("technologygcp") {
          from("org.eclipse.edc:technology-gcp-versions:$VERSION")
        }
        create("runtimemetamodel"){
          from("org.eclipse.edc:runtime-metamodel-versions:$VERSION")
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
metaModelVersion=$VERSION
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
  git clone "https://github.com/eclipse-edc/$component"
done

# if the version variable is set, set it in the various gradle.properties and settings.gradle.kts files, otherwise leave the old version
if [ -n "$VERSION" ]
then
  # read the old version from the Connector's gradle.properties
  oldVersion=$(grep "version" Connector/gradle.properties  | awk -F= '{print $2}')
  sed -i "s#$oldVersion#$VERSION#g" $(find . -name "gradle.properties")
  sed -i "s#$oldVersion#$VERSION#g" $(find . -name "settings.gradle.kts")
  sed -i "s#$oldVersion#$VERSION#g" $(find . -name "libs.versions.toml")
  # sets version in GradlePlugins/DefaultDependencyConvention and in ConnectorServiceImpl (there should be a better way)
  sed -i "s#$oldVersion#$VERSION#g" $(find . -name "*.java")
fi

# prebuild and publish plugins and modules to local repository, this needed to permit the all-in-one publish later
versionProp=""
if [ ! -z "$VERSION" ]
then
  versionProp="-Pversion=$VERSION"
fi

for component in "${components[@]}"
do
  # we're using gradle 7 in some components because of https://github.com/gradle-nexus/publish-plugin/issues/208
  sed -i "s#shadow = .*#shadow = { id = \"com.github.johnrengelman.shadow\", version = \"7.1.2\" }#g" ${component}/gradle/libs.versions.toml

  # make sure gradle 7.6 is used everywhere
  grep -rlz "distributionUrl=" ${component} | xargs sed -i "s#gradle-8..*-bin.zip#gradle-7.6-bin.zip#g"

  # publish artifacts to maven local
  echo "Build and publish to maven local component $component"
  cd "$component"
  ./gradlew -Pskip.signing "${versionProp}" publishToMavenLocal
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