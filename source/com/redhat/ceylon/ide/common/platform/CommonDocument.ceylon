import com.redhat.ceylon.ide.common.refactoring {
    DefaultRegion
}
shared interface CommonDocument {
    shared formal Integer getLineOfOffset(Integer offset);

    shared formal Integer getLineStartOffset(Integer line);
    shared formal Integer getLineEndOffset(Integer line);
    shared DefaultRegion getLineRegion(Integer line)
        => let (start = getLineStartOffset(line))
            DefaultRegion(start, getLineEndOffset(line) - start);
    
    shared formal String getText(Integer offset, Integer length);
    
    shared Character getChar(Integer offset) => getText(offset, 1).first else ' ';
    
    shared formal String getLineContent(Integer line);
    
    shared formal String getDefaultLineDelimiter();
}

shared class DefaultDocument(_text) satisfies CommonDocument {

    variable String _text;
    variable String[] lines = _text.linesWithBreaks.sequence();

    shared String text => _text;
    assign text {
        _text = text;
        lines = text.linesWithBreaks.sequence();
    }
    
    getDefaultLineDelimiter() => "\n";
    
    getLineContent(Integer line) => lines[line - 1] else "";
    
    getLineStartOffset(Integer line)
            => if (line == 1)
    then 0
    else lines[0..line - 2].fold(0)((size, str) => size + str.size);
    
    getLineEndOffset(Integer line)
            => lines[0..line - 1].fold(0)((size, str) => size + str.size);
    
    shared actual Integer getLineOfOffset(Integer offset) {
        variable value size = 0;
        
        for (i in 0..lines.size) {
            assert(exists line = lines[i]);
            if (size < offset) {
                size += line.size;
            } else {
                return i;
            }
        }
        
        return lines.size;
    }
    
    getText(Integer offset, Integer length)
            => text.substring(offset, offset + length);
}
