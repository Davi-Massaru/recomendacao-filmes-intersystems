Class dc.filmes Extends %Persistent
{

Property title As %String(MAXLEN = "");

Property originalTitle As %String(MAXLEN = "");

Property director As %String(MAXLEN = "");

Property popularity As %String(MAXLEN = "");

Property releaseDate As %String(MAXLEN = "");

Property genres As %String(MAXLEN = "");

Property overview As %String(MAXLEN = "");

Property keywords As %String(MAXLEN = "");

Property productionCompanies As %String(MAXLEN = "");

Property overviewVector As %Vector(DATATYPE = "DOUBLE", LEN = 384);

Storage Default
{
<Data name="filmesDefaultData">
<Value name="1">
<Value>%%CLASSNAME</Value>
</Value>
<Value name="2">
<Value>title</Value>
</Value>
<Value name="3">
<Value>originalTitle</Value>
</Value>
<Value name="4">
<Value>director</Value>
</Value>
<Value name="5">
<Value>popularity</Value>
</Value>
<Value name="6">
<Value>releaseDate</Value>
</Value>
<Value name="7">
<Value>genres</Value>
</Value>
<Value name="8">
<Value>overview</Value>
</Value>
<Value name="9">
<Value>keywords</Value>
</Value>
<Value name="10">
<Value>productionCompanies</Value>
</Value>
<Value name="11">
<Value>overviewVector</Value>
</Value>
</Data>
<DataLocation>^dc.filmesD</DataLocation>
<DefaultData>filmesDefaultData</DefaultData>
<IdLocation>^dc.filmesD</IdLocation>
<IndexLocation>^dc.filmesI</IndexLocation>
<StreamLocation>^dc.filmesS</StreamLocation>
<Type>%Storage.Persistent</Type>
}

}
