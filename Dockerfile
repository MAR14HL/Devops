# Étape 1: Build de l'application avec Maven
FROM maven:3.9.9-eclipse-temurin-17 AS build
WORKDIR /app

# Copier le fichier pom.xml et télécharger les dépendances
COPY pom.xml .
RUN mvn dependency:go-offline -B

# Copier le code source et compiler
COPY src ./src
RUN mvn clean package -DskipTests

# Étape 2: Image finale légère avec seulement le JRE
FROM eclipse-temurin:17-jre-alpine
WORKDIR /app

# Copier le JAR depuis l'étape de build
COPY --from=build /app/target/*.jar app.jar

# Exposer le port (ajustez si votre application utilise un autre port)
EXPOSE 8080

# Point d'entrée pour lancer l'application
ENTRYPOINT ["java", "-jar", "app.jar"]