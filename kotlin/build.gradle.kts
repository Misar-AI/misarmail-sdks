import com.vanniktech.maven.publish.SonatypeHost

plugins {
    kotlin("jvm") version "1.9.22"
    `java-library`
    // NOT `maven-publish` + `signing`. Those upload by PUTting each file to the
    // repository URL, but https://central.sonatype.com/api/v1/publisher/upload is
    // a bundle POST API, not a Maven repo — every PUT 404s and nothing is ever
    // published. This plugin speaks the Central Portal protocol.
    id("com.vanniktech.maven.publish") version "0.30.0"
}

group = "io.misar"
version = "5.0.2"

repositories {
    mavenCentral()
}

dependencies {
    // The client is built on java.net.http (JDK 11+) with Jackson and
    // coroutines — the previously declared OkHttp and Gson were never imported
    // by any source file, and the ones actually used were missing.
    // `api`, not `implementation`: two public functions return Flow, so the type is
    // part of this library's ABI. Under `implementation` the POM scopes it to runtime
    // and a consumer cannot compile against the published artifact at all.
    api("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
    implementation("com.fasterxml.jackson.module:jackson-module-kotlin:2.16.1")
    testImplementation(kotlin("test"))
    // Gradle 9 no longer puts the JUnit Platform launcher on the test runtime
    // classpath implicitly. Without it `gradle test` dies with "Failed to load
    // JUnit Platform" before running a single test.
    testRuntimeOnly("org.junit.platform:junit-platform-launcher")
    testImplementation("org.jetbrains.kotlinx:kotlinx-coroutines-test:1.8.0")
    testImplementation("io.mockk:mockk:1.13.9")
}

kotlin {
    jvmToolchain(17)
}

tasks.test {
    useJUnitPlatform()
}

// The sources and javadoc jars Central requires are produced by the publishing
// plugin, so declaring them here too would build two artifacts per classifier.

mavenPublishing {
    publishToMavenCentral(SonatypeHost.CENTRAL_PORTAL, automaticRelease = true)
    signAllPublications()
    coordinates("io.misar", "misarmail-kotlin", version.toString())

    pom {
        name.set("MisarMail Kotlin SDK")
        description.set(
            "Send transactional email and run marketing campaigns from Kotlin: " +
                "MisarMail's API for sends, campaigns, contacts, templates, automations, " +
                "domain/DMARC checks, address validation, tracking and analytics, " +
                "with coroutines, retries and Flow SSE streams."
        )
        url.set("https://www.misarmail.com")
        inceptionYear.set("2026")
        organization {
            name.set("Misar AI Technology Private Limited")
            url.set("https://misar.io")
        }
        licenses {
            license {
                name.set("MIT License")
                url.set("https://opensource.org/licenses/MIT")
                distribution.set("repo")
            }
        }
        developers {
            developer {
                id.set("misar-ai")
                name.set("Misar AI")
                email.set("hello@misar.io")
                organization.set("Misar AI Technology Private Limited")
                organizationUrl.set("https://misar.io")
            }
        }
        scm {
            connection.set("scm:git:git://github.com/Misar-AI/misarmail-sdks.git")
            developerConnection.set("scm:git:ssh://github.com/Misar-AI/misarmail-sdks.git")
            url.set("https://github.com/Misar-AI/misarmail-sdks/tree/main/kotlin")
        }
        issueManagement {
            system.set("GitHub Issues")
            url.set("https://github.com/Misar-AI/misarmail-sdks/issues")
        }
        // A Maven POM has no "documentation" element. The product docs
        // live at https://docs.misar.io/mail and are linked from the
        // README shipped alongside the sources jar.
    }
}
