import ceylon.language.meta.declaration {
    Package
}
import ceylon.file {
    Directory,
    parsePath
}
shared Directory resourcesRootForPackage(Package pkg) {
    assert (is Directory testResourcesDir = parsePath("test-resources").resource,
        is Directory vfsDir = testResourcesDir.childResource(pkg.name.split('.'.equals, true).last));
    return vfsDir;
}
