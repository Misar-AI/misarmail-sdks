plugins {
    kotlin("jvm") version "1.9.22"
    `java-library`
    `maven-publish`
    signing
}

group = "io.misar"
version = "1.0.0"

repositories {
    mavenCentral()
}

dependencies {
    // The client is built on java.net.http (JDK 11+) with Jackson and
    // coroutines — the previously declared OkHttp and Gson were never imported
    // by any source file, and the ones actually used were missing.
    implementation("org.jetbrains.kotlinx:kotlinx-coroutines-core:1.8.0")
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

java {
    withSourcesJar()
    withJavadocJar()
}

publishing {
    publications {
        create<MavenPublication>("mavenJava") {
            from(components["java"])
            groupId = "io.misar"
            artifactId = "misarmail-kotlin"

            pom {
                name.set("MisarMail Kotlin SDK")
                description.set(
                    "Send transactional email and run marketing campaigns from Kotlin: " +
                        "MisarMail's API for sends, campaigns, contacts, templates, automations, " +
                        "domain/DMARC checks, address validation, tracking and analytics, " +
                        "with coroutines, retries and Flow SSE streams."
                )
                url.set("https://misarmail.com/docs/sdks/kotlin")
                licenses {
                    license {
                        name.set("MIT License")
                        url.set("https://opensource.org/licenses/MIT")
                    }
                }
                developers {
                    developer {
                        name.set("Misar AI")
                        email.set("hello@misar.io")
                        organization.set("Misar AI Technology Pvt Ltd")
                        organizationUrl.set("https://misar.io")
                    }
                }
                scm {
                    connection.set("scm:git:git://github.com/Misar-AI/misarmail-sdks.git")
                    url.set("https://github.com/Misar-AI/misarmail-sdks")
                }
            }
        }
    }

    repositories {
        maven {
            name = "central"
            url = uri("https://central.sonatype.com/api/v1/publisher/upload")
            credentials {
                username = System.getenv("OSSRH_USERNAME") ?: "" // env var — no hardcoded value here
                password = System.getenv("OSSRH_PASSWORD") ?: "" // env var — no hardcoded value here
            }
        }
    }
}

signing {
    val gpgPrivateKey = System.getenv("MAVEN_GPG_PRIVATE_KEY") ?: ""
    val gpgPassphrase = System.getenv("MAVEN_GPG_PASSPHRASE") ?: ""
    useInMemoryPgpKeys(gpgPrivateKey, gpgPassphrase)
    sign(publishing.publications["mavenJava"])
}
