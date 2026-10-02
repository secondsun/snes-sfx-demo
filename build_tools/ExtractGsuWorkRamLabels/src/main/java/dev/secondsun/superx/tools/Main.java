package dev.secondsun.superx.tools;

import java.io.File;
import java.io.IOException;
import java.nio.file.*;
import java.nio.file.attribute.BasicFileAttributes;
import java.util.ArrayList;
import java.util.Arrays;
import java.util.List;
import java.util.stream.Collectors;

import static java.nio.file.FileVisitResult.CONTINUE;
import static java.util.stream.Collectors.joining;

public class Main {

    public static void main(String[] args) throws IOException {

        if (args.length != 1) {
            throw new IllegalArgumentException("Wrong number of arguments");
        }

        var pathArgument = args[0];
        var path = Paths.get(pathArgument);
        if (!Files.exists(path)) {
            throw new IllegalArgumentException("File not found");
        } else if (!Files.isDirectory(path)) {
            throw new IllegalArgumentException("Not a directory");
        }

        final var sgsFiles = new ArrayList<File>();

        FileVisitor<? super Path> visitor = new FileVisitor<Path>() {

            @Override
            public FileVisitResult preVisitDirectory(Path dir, BasicFileAttributes attrs) throws IOException {
                return CONTINUE;
            }

            @Override
            public FileVisitResult visitFile(Path file, BasicFileAttributes attrs) throws IOException {
                if (!Files.isDirectory(file)) {
                    if (file.endsWith(".sgs")) {
                        sgsFiles.add(file.toFile());
                    }
                }
                return CONTINUE;
            }

            @Override
            public FileVisitResult visitFileFailed(Path file, IOException exc) throws IOException {
                return CONTINUE;
            }

            @Override
            public FileVisitResult postVisitDirectory(Path dir, IOException exc) throws IOException {
                return CONTINUE;
            }
        };

        Files.walkFileTree(path, visitor);




    }


}
