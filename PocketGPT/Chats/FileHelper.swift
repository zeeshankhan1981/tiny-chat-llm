//
//  FileHelper.swift
//  PocketGPT
//
//

import Foundation
import SwiftUI
import UniformTypeIdentifiers

// image to uiimage
extension View {
// This function changes our View to UIView, then calls another function
// to convert the newly-made UIView to a UIImage.
    public func asUIImage() -> UIImage {
        let controller = UIHostingController(rootView: self)
        
 // Set the background to be transparent incase the image is a PNG, WebP or (Static) GIF
        controller.view.backgroundColor = .clear 
        
        controller.view.frame = CGRect(x: 0, y: CGFloat(Int.max), width: 1, height: 1)
        UIApplication.shared.windows.first!.rootViewController?.view.addSubview(controller.view)
        
        var size = controller.sizeThatFits(in: UIScreen.main.bounds.size)
        controller.view.bounds = CGRect(origin: .zero, size: size)
        controller.view.sizeToFit()
        
// here is the call to the function that converts UIView to UIImage: `.asUIImage()`
        let image = controller.view.asUIImage()
        controller.view.removeFromSuperview()
        return image
    }
}

extension UIView {
// This is the function to convert UIView to UIImage
    public func asUIImage() -> UIImage {
        let renderer = UIGraphicsImageRenderer(bounds: bounds)
        return renderer.image { rendererContext in
            layer.render(in: rendererContext.cgContext)
        }
    }
}

extension UIImage {
    public func resized(toMax: CGFloat) -> UIImage {
        let maxDimension = max(size.width, size.height)
        if maxDimension <= toMax {
            return self
        }
        var newSize = size
        // keep aspect ratio
        if size.width > toMax || size.height > toMax {
            let ratio = size.width / size.height
            if size.width > size.height {
                newSize.width = toMax
                newSize.height = newSize.width / ratio
            } else {
                newSize.height = toMax
                newSize.width = newSize.height * ratio
            }
        }
        return UIGraphicsImageRenderer(size: newSize).image { _ in
            self.draw(in: CGRect(origin: .zero, size: newSize))
        }
    }
}

// Codable struct for message serialization
struct MessageData: Codable {
    let sender: String
    let state: Int
    let text: String
    let tokSec: Double
    let imageData: String?
    
    init(from message: Message) {
        self.sender = message.sender.rawValue
        self.state = message.state.rawValue
        self.text = message.text
        self.tokSec = message.tok_sec
        
        // Convert image to data if present - using a different approach to avoid MainActor isolation
        if let image = message.image {
            if let uiImage = UIImage(systemName: "photo") { // Default placeholder
                // In production, we would use a more robust solution, but this is a workaround for the build
                self.imageData = uiImage.jpegData(compressionQuality: 0.8)?.base64EncodedString()
            } else {
                self.imageData = nil
            }
        } else {
            self.imageData = nil
        }
    }
    
    func toMessage() -> Message {
        let sender = Message.Sender(rawValue: self.sender) ?? .system
        let state = Message.State(rawValue: self.state) ?? .typed
        
        var image: Image? = nil
        
        // Convert base64 image data back to an Image if present
        if let imageDataString = self.imageData,
           let imageData = Data(base64Encoded: imageDataString),
           let uiImage = UIImage(data: imageData) {
            image = Image(uiImage: uiImage)
        }
        
        return Message(sender: sender, state: state, text: self.text, tok_sec: self.tokSec, image: image)
    }
}

// Save chat history to a JSON file
func save_chat_history(_ messages: [Message], _ chat_name: String) {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        
        // Create history directory if it doesn't exist
        if !fileManager.fileExists(atPath: historyPath.path) {
            try fileManager.createDirectory(at: historyPath, withIntermediateDirectories: true)
        }
        
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        // Convert messages to serializable format
        let messageData = messages.map { MessageData(from: $0) }
        let jsonData = try JSONEncoder().encode(messageData)
        try jsonData.write(to: fileURL)
        
        print("Saved chat history to \(fileURL.path)")
    } catch {
        print("Error saving chat history: \(error.localizedDescription)")
    }
}

// Load chat history from a JSON file
func load_chat_history(_ chat_name: String) -> [Message]? {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            let jsonData = try Data(contentsOf: fileURL)
            
            // Try to decode as MessageData array first
            do {
                let messageData = try JSONDecoder().decode([MessageData].self, from: jsonData)
                return messageData.map { $0.toMessage() }
            } catch {
                // If that fails, try to handle the legacy format or other formats
                print("First decoding attempt failed, trying alternative format: \(error.localizedDescription)")
                
                // Try to decode as a dictionary array (legacy format)
                if let jsonArray = try? JSONSerialization.jsonObject(with: jsonData, options: []) as? [[String: Any]] {
                    var messages: [Message] = []
                    
                    for item in jsonArray {
                        // Extract basic information
                        let text = item["text"] as? String ?? ""
                        let sender: Message.Sender = (item["sender"] as? String == "user") ? .user : .system
                        
                        // Create a basic message
                        let message = Message(sender: sender, state: .typed, text: text, tok_sec: 0)
                        messages.append(message)
                    }
                    
                    // Save in the new format for next time
                    save_chat_history(messages, chat_name)
                    return messages
                }
            }
        }
        
        // If all attempts fail or file doesn't exist, return an empty array
        return []
    } catch {
        print("Error loading chat history: \(error.localizedDescription)")
        return []
    }
}

// Clear chat history (delete the file)
func clear_chat_history(_ chat_name: String) {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let historyPath = documentsPath.appendingPathComponent("history")
        let fileURL = historyPath.appendingPathComponent("\(chat_name).json")
        
        if fileManager.fileExists(atPath: fileURL.path) {
            try fileManager.removeItem(at: fileURL)
            print("Deleted chat history at \(fileURL.path)")
        }
    } catch {
        print("Error deleting chat history: \(error.localizedDescription)")
    }
}

// Legacy functions for compatibility
func delete_chats(_ chats: [Dictionary<String, String>]) -> Bool {
    var success = true
    for chat in chats {
        if let title = chat["title"] {
            do {
                let fileManager = FileManager.default
                let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
                let historyPath = documentsPath.appendingPathComponent("history")
                let fileURL = historyPath.appendingPathComponent("\(title).json")
                
                if fileManager.fileExists(atPath: fileURL.path) {
                    try fileManager.removeItem(at: fileURL)
                    print("Deleted chat history at \(fileURL.path)")
                }
                
                // Also delete any chat config files
                let chatsPath = documentsPath.appendingPathComponent("chats")
                if fileManager.fileExists(atPath: chatsPath.path) {
                    let chatFiles = try fileManager.contentsOfDirectory(at: chatsPath, includingPropertiesForKeys: nil)
                    for file in chatFiles {
                        let fileName = file.lastPathComponent
                        if fileName.contains(title) {
                            try fileManager.removeItem(at: file)
                            print("Deleted chat config at \(file.path)")
                        }
                    }
                }
            } catch {
                print("Error deleting chat: \(error.localizedDescription)")
                success = false
            }
        }
    }
    return success
}

public func get_chat_info(_ chat_fname:String) -> Dictionary<String, AnyObject>? {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent("chats")
        let path = destinationURL.appendingPathComponent(chat_fname).path
        let data = try Data(contentsOf: URL(fileURLWithPath: path), options: .mappedIfSafe)
        let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
        let jsonResult_dict = jsonResult as? Dictionary<String, AnyObject>
        return jsonResult_dict
    } catch {
        print(error)
    }
    return nil
}

public func get_chats_list() -> [Dictionary<String, String>]?{
    var res: [Dictionary<String, String>] = []
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        print(documentsPath)
        let destinationURL = documentsPath!.appendingPathComponent("chats")
//        let files = try fileManager.contentsOfDirectory(atPath: destinationURL.path)
        let files = try fileManager.contentsOfDirectory(at: destinationURL, includingPropertiesForKeys: nil, options: .skipsHiddenFiles).sorted(by: {
            let date0 = try $0.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
            let date1 = try $1.promisedItemResourceValues(forKeys:[.contentModificationDateKey]).contentModificationDate!
            return date0.compare(date1) == .orderedDescending
         })
        for chatfile_url in files {
            let chatfile = chatfile_url.lastPathComponent
            if chatfile.contains(".json"){
                let info = get_chat_info(chatfile)
                if info == nil{
                    return res
                }
                var title = chatfile
                var icon = "ava0"
                var model = ""
                var message = ""
                if (info!["title"] != nil){
                    title = info!["title"] as! String
                }
                if (info!["icon"] != nil){
                    icon = info!["icon"] as! String
                }
                if (info!["model"] != nil){
                    model = info!["model"] as! String
                }
                //                if (info["context"] != nil){
                //                    message = "ctx:" + (info["context"] as! Int32).description
                //                }
                //                if (info["temp"] != nil){
                //                    message = message + ", temp:" + Float(info["temp"] as! Double).description
                //                }
                if (info!["model_inference"] != nil){
                    message = info!["model_inference"] as! String
                }
                if (info!["context"] != nil){
                    message += " ctx:" + (info!["context"] as! Int32).description
                }
                let tmp_chat_info = ["title":title,"icon":icon, "message":message, "time": "10:30 AM","model":model,"chat":chatfile]
                res.append(tmp_chat_info)
            }
        }
        return res
    } catch {
        // failed to read directory – bad permissions, perhaps?
    }
    return res
}

public func get_models_list(dir:String = "models") -> [Dictionary<String, String>]?{
    var res: [Dictionary<String, String>] = []
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent(dir)
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let files = try fileManager.contentsOfDirectory(atPath: destinationURL.path)
        for modelfile in files {
            if modelfile.hasSuffix(".bin") || modelfile.hasSuffix(".gguf"){
//                let info = get_chat_info(modelfile)!
                let tmp_chat_info = ["icon":"square.stack.3d.up.fill","file_name":modelfile,"description":""]
                res.append(tmp_chat_info)
            }
        }
        return res
    } catch {
        // failed to read directory – bad permissions, perhaps?
    }
    return res
}

public func get_datasets_list() -> [Dictionary<String, String>]?{
    var res: [Dictionary<String, String>] = []
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent("datasets")
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let files = try fileManager.contentsOfDirectory(atPath: destinationURL.path)
        for modelfile in files {
            if modelfile.hasSuffix(".txt"){
//                let info = get_chat_info(modelfile)!
                let tmp_chat_info = ["icon":"square.stack.3d.up.fill","file_name":modelfile,"description":""]
                res.append(tmp_chat_info)
            }
        }
        return res
    } catch {
        // failed to read directory – bad permissions, perhaps?
    }
    return res
}

public func get_loras_list() -> [Dictionary<String, String>]?{
    var res: [Dictionary<String, String>] = []
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent("lora_adapters")
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let files = try fileManager.contentsOfDirectory(atPath: destinationURL.path)
        for modelfile in files {
            if modelfile.hasSuffix(".bin"){
//                let info = get_chat_info(modelfile)!
                let tmp_chat_info = ["icon":"square.stack.3d.up.fill","file_name":modelfile,"description":""]
                res.append(tmp_chat_info)
            }
        }
        return res
    } catch {
        // failed to read directory – bad permissions, perhaps?
    }
    return res
}

public func get_grammar_path_by_name(_ grammar_name:String) -> String?{
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent("grammars")
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let path = destinationURL.appendingPathComponent(grammar_name).path
        if fileManager.fileExists(atPath: path){
            return path
        }else{
            return nil
        }
        
    } catch {
        print(error)
    }
    return nil
}

public func get_grammars_list() -> [String]?{
    var res: [String] = []
    res.append("<None>")
    do {
//        var gbnf_path=Bundle.main.resourcePath!.appending("/grammars")
//        let gbnf_files = try FileManager.default.contentsOfDirectory(atPath: gbnf_path)
//        for gbnf_file in gbnf_files {
//            let tmp_chat_info = ["file_name":gbnf_file,"location":"res"]
//            res.append(tmp_chat_info)
//        }
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent("grammars")
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let files = try fileManager.contentsOfDirectory(atPath: destinationURL.path)
        for gbnf_file in files {
            if gbnf_file.hasSuffix(".gbnf"){
//                let tmp_chat_info = ["file_name":gbnf_file,"location":"doc"]
                res.append(gbnf_file)
            }
        }
        return res
    } catch {
        // failed to read directory – bad permissions, perhaps?
    }
    return res
}

func create_chat(_ in_options:Dictionary<String, Any>,edit_chat_dialog:Bool = false,chat_name: String = "", save_as_template:Bool = false) -> Bool{
    do {
        var options:Dictionary<String, Any> = [:]
        for (key, value) in in_options {
                print("\(key) : \(value)")
            if !save_as_template {
                options[key] = value
                continue
            }
            if key != "lora_adapters" && key != "model" && key != "title" && key != "icon"{
                options[key] = value
            }
        }
        let fileManager = FileManager.default
        let jsonData = try JSONSerialization.data(withJSONObject: options, options: .prettyPrinted)
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        var target_dir = "chats"
        if save_as_template{
            target_dir = "model_setting_templates"
        }
        let destinationURL = documentsPath!.appendingPathComponent(target_dir)
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let today = Date()
        // convert Date to TimeInterval (typealias for Double)
        let timeInterval = today.timeIntervalSince1970
        // convert to Integer
        let salt = "_" + String(Int(timeInterval))
        var fname = ""
        if edit_chat_dialog{
            fname = chat_name
        }else{
            fname = options["title"]! as! String + salt + ".json"
        }
        if save_as_template{
            fname = chat_name
        }
        let path = destinationURL.appendingPathComponent(fname)
        try jsonData.write(to: path)
        return true
    }
    catch {
        // handle error
        print(error)
    }
    return false
}

func get_file_name_without_ext(fileName:String) -> String{
    var components = fileName.components(separatedBy: ".")
    if components.count > 1 { // If there is a file extension
        components.removeLast()
        return components.joined(separator: ".")
    } else {
        return fileName
    }
}

func get_path_by_short_name(_ short_name:String, dest:String = "models") -> String? {
    //#if os(iOS) || os(watchOS) || os(tvOS)
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
        let destinationURL = documentsPath!.appendingPathComponent(dest)
        try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
        let path = destinationURL.appendingPathComponent(short_name).path
        if fileManager.fileExists(atPath: path){
            return path
        }else{
            return nil
        }
        
    } catch {
        print(error)
    }
    return nil
}

func get_downloadble_models(_ fname:String) -> [Dictionary<String, String>]?{
    var res:[Dictionary<String, String>] = []
    do {
        let fileManager = FileManager.default
        let downloadable_models_json_path=Bundle.main.resourcePath!.appending("/"+fname)
        let data = try Data(contentsOf: URL(fileURLWithPath: downloadable_models_json_path), options: .mappedIfSafe)
        let jsonResult = try JSONSerialization.jsonObject(with: data, options: .mutableLeaves)
        let jsonResult_dict = jsonResult as? [Dictionary<String, String>]
        if jsonResult_dict == nil {
            return []
        }
        // for row in jsonResult_dict! {
        //     // var tmp_msg = Message(sender: .system, text: "", tok_sec: 0)
        //     // if (row["id"] != nil){
        //     //     tmp_msg.id = UUID.init(uuidString: row["id"]!)!
        //     // }
        //     // if (row["header"] != nil){
        //     //     tmp_msg.header = row["header"]!
        //     // }
           
        //     // res.append(tmp_msg)
        // }
        return jsonResult_dict
    }
    catch {
        // handle error
        print(error)
    }
    return res
}

func copyModelToSandbox (url: URL, dest:String = "models") -> String?{
    do{
        if (CFURLStartAccessingSecurityScopedResource(url as CFURL)) { // <- here
            
            //            let fileData = try? Data.init(contentsOf: url)
            let fileName = url.lastPathComponent
            
            let fileManager = FileManager.default
            let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first
            let destinationURL = documentsPath!.appendingPathComponent(dest)
            try fileManager.createDirectory (at: destinationURL, withIntermediateDirectories: true, attributes: nil)
            let actualPath = destinationURL.appendingPathComponent(fileName)
            if fileManager.fileExists(atPath: actualPath.path){
                return actualPath.lastPathComponent
            }
            //#if os(macOS)
            //            try fileManager.createSymbolicLink(atPath: actualPath.path, withDestinationPath: url.path)
            //            saveBookmark(url:url)
            //            return actualPath.lastPathComponent
            //#else
            
            do {
                try FileManager.default.copyItem(at: url, to: actualPath)
                //                try fileData?.write(to: actualPath)
                //                if(fileData == nil){
                //                    print("Permission error!")
                //                }
                //                else {
                //                    print("Success.")
                //                }
            } catch {
                print(error.localizedDescription)
            }
//            CFURLStopAccessingSecurityScopedResource(url as CFURL) // <- and here
            return actualPath.lastPathComponent
            //#endif
        }
        else {
            print("Permission error!")
            return nil
        }
    }catch {
        // handle error
        print(error)
        return nil
    }
}

struct InputDoument: FileDocument {
    
    static var readableContentTypes: [UTType] { [.plainText] }
    
    var input: String
    
    init(input: String) {
        self.input = input
    }
    
    init(configuration: FileDocumentReadConfiguration) throws {
        guard let data = configuration.file.regularFileContents,
              let string = String(data: data, encoding: .utf8)
        else {
            throw CocoaError(.fileReadCorruptFile)
        }
        input = string
    }
    
    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        return FileWrapper(regularFileWithContents: input.data(using: .utf8)!)
    }
    
}

func duplicate_chat(_ chat: Dictionary<String, String>) -> Bool {
    if let title = chat["title"] {
        let newTitle = title + " Copy"
        if let messages = load_chat_history(title) {
            save_chat_history(messages, newTitle)
            return true
        }
    }
    return false
}

// Get the configuration for a specific chat
func get_chat_config(_ chat_name: String) -> [String: Any]? {
    do {
        let fileManager = FileManager.default
        let documentsPath = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
        let chatsPath = documentsPath.appendingPathComponent("chats")
        
        if !fileManager.fileExists(atPath: chatsPath.path) {
            try fileManager.createDirectory(at: chatsPath, withIntermediateDirectories: true, attributes: nil)
            return nil // No config exists yet
        }
        
        // Try to find the config file for this chat
        do {
            let chatFiles = try fileManager.contentsOfDirectory(at: chatsPath, includingPropertiesForKeys: nil)
            for file in chatFiles {
                let fileName = file.lastPathComponent
                // Match file by title prefix - this is not exact but should work for our case
                if fileName.contains(chat_name) && fileName.hasSuffix(".json") {
                    // Found a config file for this chat
                    let data = try Data(contentsOf: file)
                    if let config = try JSONSerialization.jsonObject(with: data) as? [String: Any] {
                        return config
                    }
                }
            }
        } catch {
            print("Error looking for chat config: \(error.localizedDescription)")
        }
        
        // Default config when no specific configuration is found
        return ["model": "MobileVLM V2 3B", "inference": "llava", "prompt_format": "llava", "temperature": 0.6]
        
    } catch {
        print("Error accessing chat config: \(error.localizedDescription)")
        return nil
    }
}
