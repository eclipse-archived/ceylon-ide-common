shared Boolean equalsWithNulls<OneType, OtherType>(OneType? one, OtherType? other, Boolean(OtherType)(OneType) equals=OneType.equals, Boolean twoNullsAreEqual=true)
    given OneType satisfies Object
    given OtherType satisfies Object {

    if (exists one, exists other) {
        return equals(one)(other);
    } else {
        return twoNullsAreEqual && one is Null && other is Null;
    }
}