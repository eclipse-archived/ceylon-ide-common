import java.lang {
    ObjectArray,
    JString=String
}

shared class DefaultRegion(start, length) {
    shared Integer start;
    shared Integer length;
    
    string => "[``start``-``length``]";
}

shared interface ExtractLinkedModeEnabled<Region=DefaultRegion> {
    shared formal variable Region? typeRegion;
    shared formal variable Region? decRegion;
    shared formal variable Region? refRegion;

    shared formal Region newRegion(Integer start, Integer length);

    shared formal ObjectArray<JString> nameProposals;
}
