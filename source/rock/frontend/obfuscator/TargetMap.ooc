import io/[FileReader]
import text/[StringTokenizer]
import structs/[ArrayList, HashMap]

TargetMapEntry: class {
    oldName: String
    newName: String
    oldSuffix: String
    newSuffix: String
    init: func (=oldName, =newName, =oldSuffix, =newSuffix)
    getOldName: func -> String { oldName }
    getNewName: func -> String { newName }
    getOldSuffix: func -> String { oldSuffix }
    getNewSuffix: func -> String { newSuffix }
    toString: func -> String {
        oldSuffix ? "#{oldName}~#{oldSuffix}:#{newName}~#{newSuffix}" : "#{oldName}:#{newName}"
    }
}

TargetMap: class extends HashMap<String, TargetMapEntry> {
    init: func { super(64) }
    readMappingFile: static func (filename: String) -> This {
        result := This new()
        reader := FileReader new(filename)
        content := ""
        while (reader hasNext?()) {
            content = content append(reader read())
        }
        reader close()
        entries := content split('\n', false)
        for (rawEntry in entries) {
            entry := rawEntry trim()
            if (entry[0] == '#') {
                continue
            }
            entryPair := entry split(':')
            if (entryPair size > 1) {
                if (entryPair[0] contains?('.')) {
                    oldNameSuffixPair := entryPair[0] split('~')
                    newNameSuffixPair := entryPair[1] split('~')
                    oldSuffix := oldNameSuffixPair size > 1 ? oldNameSuffixPair[1] : null
                    newSuffix := newNameSuffixPair size > 1 ? newNameSuffixPair[1] : null
                    result put(entryPair[0], TargetMapEntry new(oldNameSuffixPair[0], newNameSuffixPair[0], oldSuffix, newSuffix))
                } else {
                    result put(entryPair[0], TargetMapEntry new(entryPair[0], entryPair[1], null, null))
                }
            }
        }
        result
    }
}
