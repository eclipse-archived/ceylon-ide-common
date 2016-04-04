shared Result? ifExists<Result,Param>(Param? p, Result(Param) f) =>
        if (exists p) then f(p) else null;
