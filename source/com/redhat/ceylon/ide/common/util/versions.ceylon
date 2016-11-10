import com.redhat.ceylon.common {
    Versions
}
shared Boolean ceylonVersionHasBeenReleased(String version) =>
        !version.endsWith("SNAPSHOT");

shared [String*] versionsAvailableForBoostrap = 
        [ for (version in Versions.jvmVersions*.version)
          if (! version.startsWith("0.") && ceylonVersionHasBeenReleased(version))
          version ]
        .reversed;

