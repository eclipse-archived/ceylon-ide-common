class AClass() {
    shared void method() {}
    shared Integer field=0;
    shared void m() {}
    shared Integer f=0;
}

void run() {
    value a = AClass();

    a.method();
    print(a.method());
    value i1 = a.field;
    print(a.field);

    a.m();
    print(a.m());
    value i2 = a.f;
    print(a.f);

    value aClass = AClass();

    aClass.method();
    print(aClass.method());
    value i3 = aClass.field;
    print(aClass.field);

    aClass.m();
    print(aClass.m());
    value i4 = aClass.f;
    print(aClass.f);
}
