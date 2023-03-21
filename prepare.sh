#!/bin/bash

set -ve

# the components that need to be built
declare -a components=("GradlePlugins" "Connector" "IdentityHub" "RegistrationService" "FederatedCatalog")

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
        create("libs") {
            from("org.eclipse.edc:edc-versions:$VERSION")
            // this is not part of the published EDC Version Catalog, so we'll just "amend" it
            library("dnsOverHttps", "com.squareup.okhttp3", "okhttp-dnsoverhttps").versionRef("okhttp")
            version("picocli", "4.6.3")
            version("googleFindBugs", "3.0.2")
            version("openApiTools", "0.2.1")
            version("swaggerAnnotation", "1.5.22")
            library("swagger-jaxrs", "io.swagger.core.v3", "swagger-jaxrs2-jakarta").version("2.1.13")

            library("picocli-core", "info.picocli", "picocli").versionRef("picocli")
            library("picocli-codegen", "info.picocli", "picocli-codegen").versionRef("picocli")
            library("google-findbugs-jsr305", "com.google.code.findbugs", "jsr305").versionRef("googleFindBugs")
            library(
                "openapi-jackson-databind-nullable",
                "org.openapitools",
                "jackson-databind-nullable"
            ).versionRef("openApiTools")
            library("swagger-annotations", "io.swagger", "swagger-annotations").versionRef("swaggerAnnotation")

        }
        create("identityHub") {
            version("ih", "$VERSION")
            library("spi-core", "org.eclipse.edc", "identity-hub-spi").versionRef("ih")
            library("core", "org.eclipse.edc", "identity-hub").versionRef("ih")
            library("core-api", "org.eclipse.edc", "identity-hub-api").versionRef("ih")
            library("core-client", "org.eclipse.edc", "identity-hub-client").versionRef("ih")
            library("core-verifier", "org.eclipse.edc", "identity-hub-credentials-verifier").versionRef("ih")

            library(
                "ext-verifier-jwt", "org.eclipse.edc", "identity-hub-verifier-jwt"
            ).versionRef("ih")
            library(
                "ext-credentials-jwt", "org.eclipse.edc", "identity-hub-credentials-jwt"
            ).versionRef("ih")

        }
        create("edc") {
            version("edc", "$VERSION")
            library("util", "org.eclipse.edc", "util").versionRef("edc")
            library("boot", "org.eclipse.edc", "boot").versionRef("edc")

            // DPF modules
            library("api-management", "org.eclipse.edc", "management-api").versionRef("edc")
            library("api-management-config", "org.eclipse.edc", "management-api-configuration").versionRef("edc")
            library("api-observability", "org.eclipse.edc", "api-observability").versionRef("edc")
            library("config-filesystem", "org.eclipse.edc", "configuration-filesystem").versionRef("edc")
            library("core-api", "org.eclipse.edc", "api-core").versionRef("edc")
            library("core-connector", "org.eclipse.edc", "connector-core").versionRef("edc")
            library("core-controlPlane", "org.eclipse.edc", "control-plane-core").versionRef("edc")
            library("core-controlplane", "org.eclipse.edc", "control-plane-core").versionRef("edc")
            library("core-identity-did", "org.eclipse.edc", "identity-did-core").versionRef("edc")
            library("core-jersey", "org.eclipse.edc", "jersey-core").versionRef("edc")
            library("core-jetty", "org.eclipse.edc", "jetty-core").versionRef("edc")
            library("core-junit", "org.eclipse.edc", "junit").versionRef("edc")
            library("core-micrometer", "org.eclipse.edc", "micrometer-core").versionRef("edc")
            library("core-sql", "org.eclipse.edc", "sql-core").versionRef("edc")
            library("core-stateMachine", "org.eclipse.edc", "state-machine").versionRef("edc")
            library("dpf-framework", "org.eclipse.edc", "data-plane-framework").versionRef("edc")
            library("dpf-selector-client", "org.eclipse.edc", "data-plane-selector-client").versionRef("edc")
            library("dpf-selector-core", "org.eclipse.edc", "data-plane-selector-core").versionRef("edc")
            library("dpf-selector-spi", "org.eclipse.edc", "data-plane-selector-spi").versionRef("edc")
            library("dpf-transferclient", "org.eclipse.edc", "data-plane-transfer-client").versionRef("edc")
            library("ext-azure-cosmos-core", "org.eclipse.edc", "azure-cosmos-core").versionRef("edc")
            library("ext-azure-test", "org.eclipse.edc", "azure-test").versionRef("edc")
            library("ext-configuration-filesystem", "org.eclipse.edc", "configuration-filesystem").versionRef("edc")
            library("ext-http", "org.eclipse.edc", "http").versionRef("edc")
            library("ext-identity-did-core", "org.eclipse.edc", "identity-did-core").versionRef("edc")
            library("ext-identity-did-crypto", "org.eclipse.edc", "identity-did-crypto").versionRef("edc")
            library("ext-identity-did-web", "org.eclipse.edc", "identity-did-web").versionRef("edc")
            library("ext-jdklogger", "org.eclipse.edc", "monitor-jdk-logger").versionRef("edc")
            library("ext-micrometer-jersey", "org.eclipse.edc", "jersey-micrometer").versionRef("edc")
            library("ext-micrometer-jetty", "org.eclipse.edc", "jetty-micrometer").versionRef("edc")
            library("ext-observability", "org.eclipse.edc", "api-observability").versionRef("edc")
            library("ext-vault-azure", "org.eclipse.edc", "vault-azure").versionRef("edc")
            library("ext-vault-filesystem", "org.eclipse.edc", "vault-filesystem").versionRef("edc")
            library("iam-mock", "org.eclipse.edc", "iam-mock").versionRef("edc")
 //           library("ids", "org.eclipse.edc", "ids").versionRef("edc")
            library("junit", "org.eclipse.edc", "junit").versionRef("edc")
            library("spi-aggregate-service", "org.eclipse.edc", "aggregate-service-spi").versionRef("edc")
            library("spi-catalog", "org.eclipse.edc", "catalog-spi").versionRef("edc")
            library("spi-core", "org.eclipse.edc", "core-spi").versionRef("edc")
            library("spi-http", "org.eclipse.edc", "http-spi").versionRef("edc")
            library("spi-identity-did", "org.eclipse.edc", "identity-did-spi").versionRef("edc")
            library("spi-ids", "org.eclipse.edc", "ids-spi").versionRef("edc")
            library("spi-policy-engine", "org.eclipse.edc", "policy-engine-spi").versionRef("edc")
            library("spi-transaction", "org.eclipse.edc", "transaction-spi").versionRef("edc")
            library("spi-transaction-datasource", "org.eclipse.edc", "transaction-datasource-spi").versionRef("edc")
            library("spi-web", "org.eclipse.edc", "web-spi").versionRef("edc")

            bundle(
                "connector",
                listOf("boot", "core-connector", "core-jersey", "core-controlplane", "api-observability")
            )

            bundle(
                "dpf",
                listOf(
                    "dpf-transferclient",
                    "dpf-selector-client",
                    "dpf-selector-spi",
                    "dpf-selector-core",
                    "dpf-framework"
                )
            )

        }
    }
}

EOF


# create gradle.properties file for the release
cat << EOF > gradle.properties
groupId=org.eclipse.edc
javaVersion=11
version=$VERSION
defaultVersion=$VERSION
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

# if the version variable is set, set it in the various gradle.properties and settings.gradle.kts files, otherwise leave 0.0.1-SNAPSHOT
if [ ! -z "$VERSION" ]
then
  sed -i "s#defaultVersion=0.0.1-SNAPSHOT#defaultVersion=$VERSION#g" $(find . -name "gradle.properties")
  sed -i "s#metaModelVersion=0.0.1-SNAPSHOT#metaModelVersion=$VERSION#g" $(find . -name "gradle.properties")
  sed -i "s#annotationProcessorVersion=0.0.1-SNAPSHOT#annotationProcessorVersion=$VERSION#g" $(find . -name "gradle.properties")

  sed -i "s#edcGradlePluginsVersion=0.0.1-SNAPSHOT#edcGradlePluginsVersion=$VERSION#g" $(find . -name "gradle.properties")

  sed -i "s#0.0.1-SNAPSHOT#$VERSION#g" $(find . -name "settings.gradle.kts")
  # sets version in GradlePlugins/DefaultDependencyConvention and in ConnectorServiceImpl (there should be a better way)
  sed -i "s#0.0.1-SNAPSHOT#$VERSION#g" $(find . -name "*.java")

  # put version in the gradle.properties files
  sed -i "$ a version=$VERSION" $(find . -name "gradle.properties")
fi

# prebuild and publish plugins and modules to local repository, this needed to permit the all-in-one publish later
versionProp=""
if [ ! -z "$VERSION" ]
then
  versionProp="-Pversion=$VERSION"
fi

for component in "${components[@]}"
do
  # add mavenLocal() to the plugin management (this should be already in place)
  sed -i '/.*gradlePluginPortal()/a mavenLocal()' $component/settings.gradle.kts

  # publish artifacts to maven local
  echo "Build and publish to maven local component $component"
  cd "$component"
  ./gradlew -Pskip.signing "${versionProp}" publishToMavenLocal
  cd ..
done

for component in "${components[@]}"
do
  # copy all the component modules into the main settings, adding the component name in the front of it
  cat $component/settings.gradle.kts | grep "include(" | grep -v "system-tests" | grep -v "launcher" | grep -v "data-plane-integration-tests" | sed "s/\":/\":$component:/g" >> settings.gradle.kts

  # update all the dependency with the new project tree
  sed -i "s#project(\":#project(\":$component:#g" $(find $component -name "build.gradle.kts")

  # remove unneeded stuff
  rm -rf $component/system-tests
  rm -rf $component/launcher
  rm -rf $component/launchers
done

# update the openapi path for registration service rest client generation
sed -i "s#rootDir/resources/openapi/yaml/registration-service-api.yaml#rootDir/RegistrationService/resources/openapi/yaml/registration-service-api.yaml#g" $(find RegistrationService -name "build.gradle.kts")

# remove the dependency plugin part in connector
sed -i '95,101d' Connector/build.gradle.kts

# not sure that the next part is needed
cat << EOF >> Connector/build.gradle.kts

dependencies {
    implementation(":GradlePlugins")
}
EOF

cat << EOF >> IdentityHub/build.gradle.kts

dependencies {
    implementation(":Connector")
}
EOF

cat << EOF >> FederatedCatalog/build.gradle.kts

dependencies {
    implementation(":IdentityHub")
}
EOF

cat << EOF >> RegistrationService/build.gradle.kts

dependencies {
    implementation(":IdentityHub")
}
EOF

# Gradle 8 is required for v8.x of the Shadow Plugin -> replace all occurrences
grep -rlz "com.github.johnrengelman.shadow" --exclude prepare.sh | xargs sed -i 's/shadow") version "8.*"/shadow") version "7.1.2"/g'
