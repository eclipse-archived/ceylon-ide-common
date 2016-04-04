import com.redhat.ceylon.ide.common.util {
    Indents
}

shared interface IndentsServicesConsumer<Document> {
    shared Indents<Document> indents => platformServices.indents<Document>();
}