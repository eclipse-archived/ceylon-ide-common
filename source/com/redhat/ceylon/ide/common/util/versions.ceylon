import com.redhat.ceylon.common {
    Versions
}
shared Boolean ceylonVersionHasBeenReleased(String version) =>
        !version.contains("SNAPSHOT");

shared [String*] versionsAvailableForBoostrap = 
        Versions.jvmVersions.array.coalesced
        .map((versionDetail) => 
            versionDetail.version)
        .filter((version) => 
            ! version.startsWith("0.") &&
            ceylonVersionHasBeenReleased(version))
        .sequence()
        .reversed;

