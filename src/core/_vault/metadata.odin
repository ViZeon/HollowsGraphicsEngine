package vault

Metadata :: struct {
    id:      int,      // index of this Metadata in vault.arrays[.Metadata]
    index:   int,
    name:    string,
    valid:   bool,
    type_id: Type_ID,
}