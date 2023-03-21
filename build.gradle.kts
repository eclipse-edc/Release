/*
 *  Copyright (c) 2022 Microsoft Corporation
 *
 *  This program and the accompanying materials are made available under the
 *  terms of the Apache License, Version 2.0 which is available at
 *  https://www.apache.org/licenses/LICENSE-2.0
 *
 *  SPDX-License-Identifier: Apache-2.0
 *
 *  Contributors:
 *       Microsoft Corporation - initial API and implementation
 *
 */

plugins {
    checkstyle
    `maven-publish`
    signing
    `java-library`
    `version-catalog`
    id("org.gradle.crypto.checksum") version "1.4.0"
    id("io.github.gradle-nexus.publish-plugin") version "1.3.0"
    id("com.gradle.plugin-publish") version "1.1.0" apply false
}

val groupId: String by project
val version: String by project
val actualVersion: String = version
val edcScmConnection: String by project
val edcWebsiteUrl: String by project
val edcScmUrl: String by project
val javaVersion: String by project
val annotationProcessorVersion: String by project

buildscript {
    repositories {
        mavenLocal()
        mavenCentral()
    }
    dependencies {
        val edcGradlePluginsVersion: String by project
        classpath("org.eclipse.edc.edc-build:org.eclipse.edc.edc-build.gradle.plugin:${edcGradlePluginsVersion}")
    }
}

allprojects {
    apply(plugin = "org.eclipse.edc.edc-build")
    apply(plugin = "maven-publish")
    version = actualVersion
    group = groupId

    repositories {
        mavenLocal()
        mavenCentral()
    }

    // for all gradle plugins:
    pluginManager.withPlugin("java-gradle-plugin") {
        apply(plugin = "com.gradle.plugin-publish")
    }

    // for all java libs:
    pluginManager.withPlugin("java-library") {
        java {
            val javaVersion = 11
            toolchain {
                languageVersion.set(JavaLanguageVersion.of(javaVersion))
            }
            tasks.withType(JavaCompile::class.java) {
                // making sure the code does not use any APIs from a more recent version.
                // Ref: https://docs.gradle.org/current/userguide/building_java_projects.html#sec:java_cross_compilation
                options.release.set(javaVersion)
            }
            withJavadocJar()
            withSourcesJar()
        }
    }

    configure<org.eclipse.edc.plugins.edcbuild.extensions.BuildExtension> {
        versions {
            projectVersion.set(actualVersion)
            metaModel.set(actualVersion)

        }
        pom {
            projectName.set(project.name)
            description.set("edc :: ${project.name}")
            projectUrl.set(edcWebsiteUrl)
            scmConnection.set(edcScmConnection)
            scmUrl.set(edcScmUrl)
        }
        swagger {
            title.set((project.findProperty("apiTitle") ?: "EDC REST API") as String)
            description =
                (project.findProperty("apiDescription") ?: "EDC REST APIs - merged by OpenApiMerger") as String
            outputFilename.set(project.name)
            outputDirectory.set(file("${rootProject.projectDir.path}/resources/openapi/yaml"))
        }
        javaLanguageVersion.set(JavaLanguageVersion.of(javaVersion))
    }

    // configure which version of the annotation processor to use. defaults to the same version as the plugin
    configure<org.eclipse.edc.plugins.autodoc.AutodocExtension> {
        processorVersion.set(annotationProcessorVersion)
        outputDirectory.set(project.buildDir)
    }

    tasks.withType<Jar> {
        metaInf {
            from("${rootProject.projectDir.path}/NOTICE.md")
            from("${rootProject.projectDir.path}/LICENSE")
        }
    }

    val signingTasks: TaskCollection<Sign> = tasks.withType()
    tasks.withType<PublishToMavenRepository>().configureEach{
        mustRunAfter(signingTasks)
    }
}
