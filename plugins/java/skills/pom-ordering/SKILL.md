---
name: pom-ordering
description: Enforce Maven POM dependency ordering rules. This skill should be used when editing pom.xml files.
---

## Ordering Rules

First, group dependencies by scope (compile, runtime, test).

Within each scope, group by groupId in this order:

1. First-party (${project.groupId} or modules within the project)
2. cool.klass
3. io.liftwizard
4. org.eclipse.collections
5. io.dropwizard
6. Other third-party libraries
7. Jakarta

## Region Comment Structure

Use region comments for each groupId+scope combination:

- `<!--region Project compile dependencies -->`
- `<!--region Project runtime dependencies -->`
- `<!--region Klass compile dependencies -->`
- `<!--region Klass runtime dependencies -->`
- `<!--region Liftwizard compile dependencies -->`
- `<!--region Liftwizard runtime dependencies -->`
- `<!--region Compile dependencies -->` (for other dependencies)
- `<!--region Runtime dependencies -->`
- `<!--region Test dependencies -->`

Close each region with `<!--endregion [name] -->`

Within some groups, use nested regions for further organization:

- For io.liftwizard runtime: `<!--region Liftwizard bundles -->` then `<!--region Liftwizard config-->`
- For io.dropwizard: core modules first, then specialized modules

## Example Structure

```xml
<dependencies>

    <!--region Project compile dependencies -->
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>example-services</artifactId>
        <version>${project.version}</version>
    </dependency>
    <!--endregion-->

    <!--region Project runtime dependencies -->
    <dependency>
        <groupId>${project.groupId}</groupId>
        <artifactId>example-domain-model</artifactId>
        <version>${project.version}</version>
        <scope>runtime</scope>
    </dependency>
    <!--endregion-->

    <!--region Liftwizard runtime dependencies -->
    <dependency>
        <groupId>io.liftwizard</groupId>
        <artifactId>liftwizard-graphql-reladomo-meta</artifactId>
        <scope>runtime</scope>
    </dependency>

    <!--region Liftwizard bundles -->
    <dependency>
        <groupId>io.liftwizard</groupId>
        <artifactId>liftwizard-bundle-cors</artifactId>
        <scope>runtime</scope>
    </dependency>
    <!--endregion-->

    <!--region Liftwizard config-->
    <dependency>
        <groupId>io.liftwizard</groupId>
        <artifactId>liftwizard-config-logging-logstash-console</artifactId>
        <scope>runtime</scope>
    </dependency>
    <!--endregion-->
    <!--endregion-->

    <!--region Test dependencies -->
    <dependency>
        <groupId>org.junit.jupiter</groupId>
        <artifactId>junit-jupiter</artifactId>
        <scope>test</scope>
    </dependency>
    <!--endregion-->

</dependencies>
```
