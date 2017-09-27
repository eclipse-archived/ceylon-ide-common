import ceylon.collection {
    HashMap
}

import java.io {
    File,
    IOException
}
import java.util {
    Properties
}

import net.lingala.zip4j.core {
    ZipFile
}
import net.lingala.zip4j.exception {
    ZipException
}


shared Map<String,String> retrieveMappingFile(File? carFile) {
    if (exists carFile) {
        try {
            return retrieveZipMappingFile(ZipFile(carFile));
        }
        catch (ZipException e) {
            e.printStackTrace();
        }
    }
    return emptyMap;
}

shared Map<String,String> retrieveZipMappingFile(ZipFile? carFile) {
    value mapping = Properties();
    if (exists carFile, carFile.validZipFile) {
        try {
            if (exists fileHeader = carFile.getFileHeader("META-INF/mapping.txt")) {
                value zis = carFile.getInputStream(fileHeader);
                try {
                    mapping.load(zis);
                }
                finally {
                    zis.close();
                }
            }
        }
        catch (ZipException|IOException e) {
            e.printStackTrace();
        }
    }
    return map {
        for (prop in mapping.stringPropertyNames())
        prop.string -> mapping.getProperty(prop.string)
    };
}

shared Map<String,String> searchCeylonFilesForJavaImplementations
        ({String*} sources, File sourceArchive) {
    value javaImplFilesToCeylonDeclFiles = HashMap<String,String>();
    value zipFile = ZipFile(sourceArchive);
    for (sourceUnitRelativePath in sources) {
        if (sourceUnitRelativePath.endsWith(".java")) {
            String ceylonSourceUnitRelativePath;
            if (sourceUnitRelativePath=="ceylon/language/true_.java"
             || sourceUnitRelativePath=="ceylon/language/false_.java") {
                ceylonSourceUnitRelativePath
                        = "ceylon/language/Boolean.ceylon";
            }
            else {
                ceylonSourceUnitRelativePath
                        = sourceUnitRelativePath
                            .removeTerminal(".java")
                            .removeTerminal("_")
                        + ".ceylon";
            }
            if (zipFile.getFileHeader(ceylonSourceUnitRelativePath) exists) {
                javaImplFilesToCeylonDeclFiles.put(
                    sourceUnitRelativePath,
                    ceylonSourceUnitRelativePath);
            }
        }
    }
    return javaImplFilesToCeylonDeclFiles ;
}

