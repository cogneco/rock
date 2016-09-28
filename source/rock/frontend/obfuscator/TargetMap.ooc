import io/[FileReader]
import text/[StringTokenizer]
import structs/[ArrayList, HashMap]

TargetMapEntry: class {
    oldName: String
    newName: String
    init: func (=oldName, =newName)
    toString: func -> String {
        "#{oldName}:#{newName}"
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
                result put(entryPair[0], TargetMapEntry new(entryPair[0], entryPair[1]))
            }
        }
        result
    }
}
