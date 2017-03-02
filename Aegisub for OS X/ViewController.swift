//
//  ViewController.swift
//  Aegisub for OS X
//
//  Created by Nico Linnemann on 2016/05/08.
//  Copyright © 2016年 Nico Linnemann. All rights reserved.
//

import Cocoa

class ViewController: NSViewController, NSTableViewDelegate, NSTableViewDataSource, NSTextFieldDelegate {

    @IBOutlet weak var tableView: NSTableView!
    @IBOutlet weak var lineText: NSTextField!
    @IBOutlet weak var layerField: NSTextField!
    @IBOutlet weak var layerStepper: NSStepper!
    @IBOutlet weak var commentaryCheckBox: NSButton!
    @IBOutlet weak var styleField: NSComboBox!
    @IBOutlet weak var startTimeField: NSTextField!
    @IBOutlet weak var endTimeField: NSTextField!
    @IBOutlet weak var durationField: NSTextField!
    @IBOutlet weak var actorField: NSTextField!
    @IBOutlet weak var effectField: NSTextField!
    
    /*let assTags : [String] = [
    "\\\\h",
    "\\\\pos",
    "\\\\move",
    "\\\\clip",
    "\\\\iclip",
    "\\\\org",
    "\\\\fade",
    "\\\\fad",
    "\\\\i",
    "\\\\b",
    "\\\\s",
    "\\\\u",
    "\\\\bord"
    ]*/
    
    enum TextMode {
        case normal
        case inBraces, tags
        case inLua // ! applying when comment and effect containing "template or code"
        case inAmpersands, inDollars
    }
    
    enum TextModeColors {
        case normal, braces, tagValues, backSlashes, tags, newLine, luaCode
        func toColor() -> NSColor {
            switch self {
            case .braces:
                return NSColor(red: 22/255, green: 0, blue: 221/255, alpha: 1) // darkblue
            case .tagValues:
                return NSColor(red: 15/255, green: 169/255, blue: 15/255, alpha: 1) // darkgreen
            case .backSlashes:
                return NSColor(red: 200/255, green: 0, blue: 200/255, alpha: 1) // lightviolet
            case .tags:
                return NSColor(red: 156/255, green: 123/255, blue: 3/255, alpha: 1) // brown?
            case .newLine:
                return NSColor(red: 120/255, green: 120/255, blue: 120/255, alpha: 1) // grey?
            case .luaCode:
                return NSColor(red: 148/255, green: 0, blue: 211/255, alpha: 1) // darkviolet
            default: // .normal
                return NSColor(red: 0, green: 0, blue: 0, alpha: 1) // black
            }
        }
    }
    
    /*
     * **** LEVELs ****
     *
     * 1. normal
     * 2. curlyBraces
     * 3. tags
     * 4. numbers
     * 5. andSigns
     * 6. dollarSigns
     * 7. newLine
     * 8. exclamationMarks
     */
    
    enum TextPatterns {
        case exclamationMarks // only applies, when effect contains "template or code" and comment is checked
        case andSigns
        case dollarSigns
        case curlyBraces
        case newLines
        case numbers
        case tags
        case normal
        
        func getPattern() -> NSRegularExpression {
            switch self {
            case .exclamationMarks:
                return try! NSRegularExpression(pattern: "!(?:[^!]*)!", options: [])
            case .andSigns:
                return try! NSRegularExpression(pattern: "&(?:[^&]*)&", options: [])
            case .dollarSigns:
                return try! NSRegularExpression(pattern: "\\$[a-zA-Z]+", options: [])
            case .curlyBraces:
                return try! NSRegularExpression(pattern: "{(?:[^}]*)}", options: [])
            case .newLines:
                return try! NSRegularExpression(pattern: "\\N", options: [])
            case .numbers:
                return try! NSRegularExpression(pattern: "[0-9]+", options: [])
            case .tags:
                return try! NSRegularExpression(pattern: "\\\\w+", options: [])
            case .normal:
                return try! NSRegularExpression(pattern: ".*", options: [])
            }
        }
    }
    
    struct assLine {
        var line : String
        var layer : String
        var start : String
        var end : String
        var cps : String
        var style : String
        var text : String
        var comment : Bool
        var margin_l : String
        var margin_r : String
        var margin_v : String
        var actor : String
        var effect : String
    }
    
    var assLines = [Int : assLine]()
    
    var selectedLine : Int = 0
    
    override func viewDidLoad() {
        super.viewDidLoad()
        
        self.tableView.selectionHighlightStyle = NSTableViewSelectionHighlightStyle.sourceList
        self.tableView.columnAutoresizingStyle = NSTableViewColumnAutoresizingStyle.uniformColumnAutoresizingStyle
        
        
        let line = "1"
        let start = "00:00:00:00"
        let end = "00:00:05:00"
        let cps = "0"
        let layer = "0"
        let style = "Default"
        let text = ""
        
        self.assLines.updateValue(
            assLine(
                line:       line,
                layer:      layer,
                start:      start,
                end:        end,
                cps:        cps,
                style:      style,
                text:       text,
                comment:    false,
                margin_l:   "0",
                margin_r:   "0",
                margin_v:   "0",
                actor:      "",
                effect:     ""
            ),
            forKey: self.assLines.count
        )
        
        self.tableView.reloadData()
        
        self.tableView.selectRowIndexes(IndexSet(integer: selectedLine), byExtendingSelection: false)
        
        // Do any additional setup after loading the view.
    }

    override var representedObject : Any? {
        didSet {
        // Update the view, if already loaded.
        }
    }
    
    override func controlTextDidChange(_ obj: Notification) {
        
        if((obj.object as! NSTextField) == self.lineText) {
            
            checkForBrackets(lineText.stringValue, (self.assLines[selectedLine]?.comment)!, (self.assLines[selectedLine]?.effect)!)
        
            self.assLines[selectedLine]?.text = self.lineText.stringValue
            self.tableView.reloadData()
        }
        else if((obj.object as! NSTextField) == self.startTimeField || (obj.object as! NSTextField) == self.endTimeField || (obj.object as! NSTextField) == self.durationField) {
            checkTime(obj.object as! NSTextField)
        }
    }
    
    func openDocument(_ sender: AnyObject) {
        let panel = NSOpenPanel()
        
        panel.allowsMultipleSelection = false
        panel.canChooseDirectories = false
        panel.canChooseFiles = true
        panel.allowedFileTypes = ["ass"]
        
        panel.begin { (result) -> Void in
            if(result == NSModalResponseOK) {
                let resultURL = panel.url
                
                do { // Open Action here
                    
                    var documentContent = try NSString(contentsOf: resultURL!, encoding: String.Encoding.utf8.rawValue)
                    
                    documentContent = documentContent.substring(from: documentContent.range(of: "[Events]").location) as NSString
                    
                    let separator : CharacterSet = CharacterSet.newlines
                    let rows : [String] = documentContent.components(separatedBy: separator)
                    // never mind Line 0 and 1, cause they have [Events] and the Format line.
                    
                    var i : Int = 1
                    
                    self.assLines.removeAll()
                    
                    for line in rows {
                        
                        let splitted = (line as AnyObject).components(separatedBy: ",")
                        
                        // there are 10+ parts
                        
                        let layerSplit = splitted[0].components(separatedBy: " ")
                        
                        if(layerSplit[0] != "Dialogue:" && layerSplit[0] != "Comment:") {
                            continue
                        }
                        
                        let layer = layerSplit[1]
                        let start = splitted[1].replacingOccurrences(of: ".", with: ":")
                        let end = splitted[2].replacingOccurrences(of: ".", with: ":")
                        let style = splitted[3]
                        let name = splitted[4]
                        let margin_l = splitted[5]
                        let margin_r = splitted[6]
                        let margin_v = splitted[7]
                        let effect = splitted[8]
                        var text = ""
                        
                        var j = 9
                        while(j < splitted.count) {
                            if(j != splitted.count - 1) {
                                text += splitted[j] + ","
                            } else {
                                text += splitted[j]
                            }
                            j += 1
                        }
                    
                        
                        let comment = (layerSplit[0] == "Comment:" ? true : false)
                        
                        let cps = "0" // this comes later
                        
                        let line = String(i)
                        
                        self.assLines.updateValue(
                            assLine(
                                line:       line,
                                layer:      layer,
                                start:      start,
                                end:        end,
                                cps:        cps,
                                style:      style,
                                text:       text,
                                comment:    comment,
                                margin_l:   margin_l,
                                margin_r:   margin_r,
                                margin_v:   margin_v,
                                actor:      name,
                                effect:     effect
                            ),
                            
                            forKey: self.assLines.count)
                        
                        i += 1
                        
                    }
                    
                    self.tableView.reloadData()
                    
                    self.tableView.selectRowIndexes(IndexSet(integer: self.selectedLine), byExtendingSelection: false)
                    
                }
                catch let error as NSError {
                    //BLABLABLA
                    //PRINCE OF ALL SAIYANS
                    //PRIDE BLABLABLA
                    print(error)
                }
            }
        }
    }
    
    func numberOfRows(in tableView: NSTableView) -> Int {
        return self.assLines.count
    }
    
    func tableView(_ tableView: NSTableView, viewFor tableColumn: NSTableColumn?, row: Int) -> NSView? {
        
        let result : NSTableCellView = tableView.make(withIdentifier: (tableColumn?.identifier)!, owner: self) as! NSTableCellView
        
        let columnIdentifier = tableColumn!.identifier
        
        if columnIdentifier == "LineNumber" {
            result.textField?.stringValue = (self.assLines[row]?.line)!
        } else if columnIdentifier == "LineStart" {
            result.textField?.stringValue = (self.assLines[row]?.start)!
        } else if columnIdentifier == "LineEnd" {
            result.textField?.stringValue = (self.assLines[row]?.end)!
        } else if columnIdentifier == "LineCPS" {
            result.textField?.stringValue = (self.assLines[row]?.cps)!
        } else if columnIdentifier == "LineStyle" {
            result.textField?.stringValue = (self.assLines[row]?.style)!
        } else if columnIdentifier == "LineText" {
            
            let regex = try! NSRegularExpression(pattern: "\\{.*\\}", options: NSRegularExpression.Options.caseInsensitive)
            let range = NSMakeRange(0, (self.assLines[row]?.text.characters.count)!)
            
            let modString = regex.stringByReplacingMatches(in: (self.assLines[row]?.text)!, options: [], range: range, withTemplate: "\u{263C}")
            result.textField?.stringValue = modString
        }
        
        // let backgroundColor : CGColor? = NSColor.init(red: 200/255, green: 0, blue: 200/255, alpha: 0).cgColor.copy(alpha: 0.2)
        
        if self.assLines[row]?.comment == true {
            result.textField?.textColor = NSColor.init(red: 150/255, green: 0, blue: 150/255, alpha: 1)
        } else {
            result.textField?.textColor = NSColor.init(red: 0, green: 0, blue: 0, alpha: 1)
        }
        
        return result
    }
    
    func tableViewSelectionDidChange(_ notification: Notification) {
        let selectedRow = self.tableView.selectedRow
        selectedLine = selectedRow
        
        commentaryCheckBox.state = (self.assLines[selectedLine]?.comment == false ? NSOffState : NSOnState)
        layerField.stringValue = (self.assLines[selectedLine]?.layer)!
        layerStepper.stringValue = (self.assLines[selectedLine]?.layer)!
        startTimeField.stringValue = (self.assLines[selectedLine]?.start)!
        endTimeField.stringValue = (self.assLines[selectedLine]?.end)!
        durationField.stringValue = calcDuration((self.assLines[selectedLine]?.start)!, endTime: (self.assLines[selectedLine]?.end)!)
        actorField.stringValue = (self.assLines[selectedLine]?.actor)!
        effectField.stringValue = (self.assLines[selectedLine]?.effect)!
        
        
        self.lineText.stringValue = (self.assLines[selectedLine]?.text)!
        
        checkForBrackets(self.lineText.stringValue, (self.assLines[selectedLine]?.comment)!, (self.assLines[selectedLine]?.effect)!)
    }
    
    func calcDuration(_ startTime : String, endTime : String) -> String {
        let start = startTime.components(separatedBy: ":")
        let end = endTime.components(separatedBy: ":")
        let startInMs = (Int(start[0])!*60*60*1000) + (Int(start[1])!*60*1000) + (Int(start[2])!*1000) + Int(start[3])!
        let endInMs = (Int(end[0])!*60*60*1000) + (Int(end[1])!*60*1000) + (Int(end[2])!*1000) + Int(end[3])!
        
        let differenceInMs = endInMs - startInMs
        
        if(differenceInMs < 0) {
            self.endTimeField.stringValue = startTime
            return "00:00:00:00"
        }
        
        let differenceHour = differenceInMs/1000/60/60
        let differenceMinutes = (differenceInMs - (differenceHour*60*60*1000))/1000/60
        let differenceSeconds = (differenceInMs - (differenceHour*60*60*1000) - (differenceMinutes*60*1000))/1000
        let differenceRestMS = (differenceInMs - (differenceHour*60*60*1000) - (differenceMinutes*60*1000) - (differenceSeconds*1000))
        
        let difference = String(format: "%02d", differenceHour) + ":" + String(format: "%02d", differenceMinutes) + ":" + String(format: "%02d", differenceSeconds) + ":" + String(format: "%02d", differenceRestMS)
        
        return difference
        
    }
    
    func calcNewLineEnd(_ startTime : String) -> String {
        let start = startTime.components(separatedBy: ":")
        
        let startInMs = (Int(start[0])!*60*60*1000) + (Int(start[1])!*60*1000) + (Int(start[2])!*1000) + Int(start[3])!
        
        let newEndTimeMS = startInMs + 2000
        
        let newEndTimeHour = newEndTimeMS/1000/60/60
        let newEndTimeMinutes = (newEndTimeMS - (newEndTimeHour*60*60*1000))/1000/60
        let newEndTimeSeconds = (newEndTimeMS - (newEndTimeHour*60*60*1000) - (newEndTimeMinutes*60*1000))/1000
        let newEndTimeRestMS = (newEndTimeMS - (newEndTimeHour*60*60*1000) - (newEndTimeMinutes*60*1000) - (newEndTimeSeconds*1000))
        
        
        let newEndTime = String(format: "%02d", newEndTimeHour) + ":" + String(format: "%02d", newEndTimeMinutes) + ":" + String(format: "%02d", newEndTimeSeconds) + ":" + String(format: "%02d", newEndTimeRestMS)
        
        return newEndTime
    }
    
    func checkForBrackets(_ lineText : String, _ comment : Bool, _ effect : String) {
        
        let attributedString = NSMutableAttributedString(string: lineText)
        var textMode : TextMode = TextMode.normal
        let font : NSFont = NSFont.systemFont(ofSize: 17)
        var curTag = ""
        var lastMode : TextMode = TextMode.normal
        
        var i = 0
        for char in lineText.characters
        {
            if char == "!" // only apply to commented and effect lines
            {
                if comment && (effect.lowercased().contains("template") || effect.lowercased().contains("code"))
                {
                    if textMode != .inLua
                    {
                        attributedString.addAttributes([
                            NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                            NSFontAttributeName: font], range: NSMakeRange(i, 1))
                        lastMode = textMode
                        textMode = .inLua
                    }
                    else
                    {
                        attributedString.addAttributes([
                            NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                            NSFontAttributeName: font], range: NSMakeRange(i, 1))
                        textMode = lastMode
                        lastMode = .inLua
                    }
                }
                else
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
            }
            else if char == "&"
            {
                if textMode == .inBraces || textMode == .tags
                {
                    lastMode = textMode
                    textMode = .inAmpersands
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else if textMode == .inAmpersands
                {
                    textMode = lastMode
                    lastMode = .inAmpersands
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
            }
            else if char == "$"
            {
                if textMode == .inBraces || textMode == .tags || textMode == .inLua || textMode == .inDollars
                {
                    lastMode = textMode
                    textMode = .inDollars
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
            }
            else if char == "("
            {
                if textMode == .inBraces || textMode == .tags
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.tags.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else if textMode == .inLua
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
            }
            else if char == ")"
            {
                if textMode == .inBraces || textMode == .tags || textMode == .inDollars
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.tags.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else if textMode == .inLua
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
                else
                {
                    attributedString.addAttributes([
                        NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                        NSFontAttributeName: font], range: NSMakeRange(i, 1))
                }
            }
            else if char == " "
            {
                /*if textMode == .tags
                {
                    if lastMode != .normal
                    {
                        textMode = lastMode
                        lastMode = .tags
                    }
                }*/
                attributedString.addAttributes([
                    NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                    NSFontAttributeName: font], range: NSMakeRange(i, 1))
            }
            else if char == "{"
            {
                switch textMode
                {
                case .inLua:
                    attributedString.addAttributes(
                        [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                         NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    break
                default:
                    attributedString.addAttributes(
                        [NSForegroundColorAttributeName: TextModeColors.braces.toColor(),
                         NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    textMode = .inBraces
                    break
                }
            }
            else if char == "}"
            {
                switch textMode
                {
                case .inBraces, .tags:
                    attributedString.addAttributes(
                        [NSForegroundColorAttributeName: TextModeColors.braces.toColor(),
                         NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    textMode = .normal
                    break
                case .inLua, .inAmpersands:
                    attributedString.addAttributes(
                        [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                         NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    break
                default:
                    break
                }
            }
            else if char == "\\"
            {
                attributedString.addAttributes(
                    [NSForegroundColorAttributeName: TextModeColors.backSlashes.toColor(),
                     NSFontAttributeName: font], range: NSMakeRange(i, 1))
                lastMode = textMode
                textMode = .tags
                curTag = "\\"
            }
            else
            {
                let asciiValue = char.asciiValue
                if (asciiValue >= 48 && asciiValue <= 57) || asciiValue == 46 // 0-9
                {
                    if textMode == .tags
                    {
                        if curTag == "\\"
                        {
                            attributedString.addAttributes(
                                [NSForegroundColorAttributeName: TextModeColors.tags.toColor(),
                                 NSFontAttributeName: font], range: NSMakeRange(i, 1))
                            curTag = curTag + String(char)
                        }
                        else
                        {
                            attributedString.addAttributes(
                                [NSForegroundColorAttributeName: TextModeColors.tagValues.toColor(),
                                 NSFontAttributeName: font], range: NSMakeRange(i, 1))
                        }
                    }
                    else if textMode == .inLua || textMode == .inAmpersands
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                    else
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                }
                else if ((asciiValue >= 65 && asciiValue <= 90) || (asciiValue >= 97 && asciiValue <= 122)) // A-Za-z
                {
                    if textMode == .tags
                    {
                        if curTag == "\\" && asciiValue == 78 // \N
                        {
                            attributedString.addAttributes(
                                [NSForegroundColorAttributeName: TextModeColors.newLine.toColor(),
                                 NSFontAttributeName: font], range: NSMakeRange(i-1, 2))
                            curTag = ""
                            textMode = lastMode
                            lastMode = .tags
                        }
                        else if textMode == .inLua
                        {
                            attributedString.addAttributes(
                                [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                                 NSFontAttributeName: font], range: NSMakeRange(i, 1))
                        }
                        else
                        {
                            attributedString.addAttributes(
                                [NSForegroundColorAttributeName: TextModeColors.tags.toColor(),
                                 NSFontAttributeName: font], range: NSMakeRange(i, 1))
                            curTag = curTag + String(char)
                        }
                    }
                    else if textMode == .inLua || textMode == .inAmpersands || textMode == .inDollars
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                    else
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                }
                else
                {
                    if textMode == .inLua || textMode == .inAmpersands
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.luaCode.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                    else if textMode == .inDollars
                    {
                        textMode = lastMode
                        lastMode = .inDollars
                        attributedString.addAttributes([
                            NSForegroundColorAttributeName: TextModeColors.tags.toColor(),
                            NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                    else
                    {
                        attributedString.addAttributes(
                            [NSForegroundColorAttributeName: TextModeColors.normal.toColor(),
                             NSFontAttributeName: font], range: NSMakeRange(i, 1))
                    }
                }
            }
            i = i + 1
        }
        
        self.lineText.attributedStringValue = attributedString
        
        
    }
    
    func checkTime(_ object : NSTextField) {
        
        let ranges : [NSRange]
        
        do {
            let regex = try NSRegularExpression(pattern: "([A-Za-z]+)", options: [])
            ranges = regex.matches(in: object.stringValue, options: [], range: NSMakeRange(0, object.stringValue.characters.count)).map {$0.range}
        } catch {
            ranges = []
        }
        
        if(ranges.count > 0) {
            for range in ranges {
                let newRange = object.stringValue.characters.index(object.stringValue.startIndex, offsetBy: range.location) ..< object.stringValue.characters.index(object.stringValue.startIndex, offsetBy: range.location + range.length)
                object.stringValue.removeSubrange(newRange)
                
            }
            return
        }
        
        var timeStringArray = object.stringValue.components(separatedBy: ":")
        var timeInMS : Int = 0
        var multiplier : Int = (60*60*1000)
        var idx : Int = 0
        
        for timeString in timeStringArray {
            if timeString.characters.count > 2 {
                timeStringArray[idx].remove(at: timeString.characters.index(timeString.startIndex, offsetBy: 2))
            }
            
            timeInMS += Int(timeString)!*multiplier
            if multiplier == (60*60*1000) {
                multiplier = 60*1000
            }
            else if multiplier == (60*1000) {
                multiplier = 1000
            }
            else {
                multiplier = 1
            }
            idx += 1
        }
        
        
        let newTimeHour = timeInMS/1000/60/60
        let newTimeMinutes = (timeInMS - (newTimeHour*60*60*1000))/1000/60
        let newTimeSeconds = (timeInMS - (newTimeHour*60*60*1000) - (newTimeMinutes*60*1000))/1000
        let newTimeRestMS = ((timeInMS - (newTimeHour*60*60*1000) - (newTimeMinutes*60*1000) - (newTimeSeconds*1000)) >= 100 ? (timeInMS - (newTimeHour*60*60*1000) - (newTimeMinutes*60*1000) - (newTimeSeconds*1000))/10 : (timeInMS - (newTimeHour*60*60*1000) - (newTimeMinutes*60*1000) - (newTimeSeconds*1000)))
        
        let newTime = String(format: "%02d", newTimeHour) + ":" + String(format: "%02d", newTimeMinutes) + ":" + String(format: "%02d", newTimeSeconds) + ":" + String(format: "%02d", newTimeRestMS)
        
        object.stringValue = newTime
        
        if(object == self.startTimeField || object == self.endTimeField) {
            self.durationField.stringValue = calcDuration(self.startTimeField.stringValue, endTime: self.endTimeField.stringValue)
        } else {
            calcTimeByDuration(self.startTimeField.stringValue, duration: self.durationField.stringValue)
        }
        
    }
    
    func calcTimeByDuration(_ startTime : String, duration : String) {
        
        let start = startTime.components(separatedBy: ":")
        let startInMs = (Int(start[0])!*60*60*1000) + (Int(start[1])!*60*1000) + (Int(start[2])!*1000) + Int(start[3])!
        
        let duration = duration.components(separatedBy: ":")
        let durationInMs = (Int(duration[0])!*60*60*1000) + (Int(duration[1])!*60*1000) + (Int(duration[2])!*1000) + Int(duration[3])!
        
        let newEndTimeMS = startInMs + durationInMs
        
        let newEndTimeHour = newEndTimeMS/1000/60/60
        let newEndTimeMinutes = (newEndTimeMS - (newEndTimeHour*60*60*1000))/1000/60
        let newEndTimeSeconds = (newEndTimeMS - (newEndTimeHour*60*60*1000) - (newEndTimeMinutes*60*1000))/1000
        let newEndTimeRestMS = (newEndTimeMS - (newEndTimeHour*60*60*1000) - (newEndTimeMinutes*60*1000) - (newEndTimeSeconds*1000))
        
        
        self.endTimeField.stringValue = String(format: "%02d", newEndTimeHour) + ":" + String(format: "%02d", newEndTimeMinutes) + ":" + String(format: "%02d", newEndTimeSeconds) + ":" + String(format: "%02d", newEndTimeRestMS)
        
    }
    
    @IBAction func textFieldAction(_ sender: NSTextField) {
        
        if sender != lineText {
            return
        }
        
        if selectedLine+1 == numberOfRows(in: self.tableView) {
            
            // create new row since there is no next
            
            let line = String(self.assLines.count+1)
            let start = (self.assLines[selectedLine]?.end)!
            let end = calcNewLineEnd((self.assLines[selectedLine]?.end)!)
            let cps = "0"
            let layer = "0"
            let style = "Default"
            let text = ""
            
            self.assLines.updateValue(
                assLine(
                    line:       line,
                    layer:      layer,
                    start:      start,
                    end:        end,
                    cps:        cps,
                    style:      style,
                    text:       text,
                    comment:    false,
                    margin_l:   "0",
                    margin_r:   "0",
                    margin_v:   "0",
                    actor:      "",
                    effect:     ""
                ),
                forKey: self.assLines.count
            )
            
            self.tableView.reloadData()
            
            self.tableView.selectRowIndexes(IndexSet(integer: selectedLine+1), byExtendingSelection: false)
            self.tableView.scrollRowToVisible(selectedLine)
            
        }
        else {
            self.tableView.selectRowIndexes(IndexSet(integer: selectedLine+1), byExtendingSelection: false)
            self.tableView.scrollRowToVisible(selectedLine)
        }
        
    }
    
    @IBAction func clickedStepper(_ sender: NSStepper) {
        layerField.stringValue = sender.stringValue
        self.assLines[selectedLine]?.layer = sender.stringValue
    }
    
    @IBAction func commentaryCheckBoxClicked(_ sender: NSButton) {
        
        let selectedRow = self.tableView.selectedRow
        
        self.assLines[selectedLine]?.comment = (sender.state == NSOnState ? true : false)
        self.tableView.reloadData()
        
        self.tableView.selectRowIndexes(IndexSet(integer: selectedRow), byExtendingSelection: false)
        
    }
}

extension Character {
    var asciiValue: Int {
        get {
            let s = String(self).unicodeScalars
            return Int(s[s.startIndex].value)
        }
    }
}
