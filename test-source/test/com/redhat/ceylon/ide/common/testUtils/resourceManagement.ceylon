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

shared Integer calculateContentOffset([String*] lines,
    Boolean findLine(Integer->String line),
    Integer findColumn(String line)) {
    value searchedLines = lines.indexed.select(findLine);
    "Exactly one line should be found"
    assert(exists searchedLine = searchedLines.first,
        searchedLines.size == 1);
    return lines.take(searchedLine.key)
            .fold(0)(
        (p, l)
                => p + l.size + 1)
            + findColumn(searchedLine.item);
}
suppressWarnings("expressionTypeNothing")
shared Integer lineColumnToOffset([String*]lines,
    "0-based line index"
    Integer line,
    "0-based column index"
    Integer column)
        => calculateContentOffset {
    lines => lines;
    function findLine(Integer->String l)
            => l.key == line;
    function findColumn(String l)
            => if (column < l.size)
    then column
    else nothing;
};
suppressWarnings("expressionTypeNothing")
shared Integer findInLines([String*]lines,
    String searchedText,
    Integer indexInText)
        => calculateContentOffset {
    lines => lines;
    function findLine(Integer->String l)
            => l.item.contains(searchedText);
    function findColumn(String line)
            => if (exists textStart = line.firstInclusion(searchedText))
    then textStart + indexInText
    else nothing;
};