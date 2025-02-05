require 'java'
java_import 'burp.ITab'
java_import 'javax.swing.JOptionPane'
java_import 'javax.swing.JPanel'
java_import 'javax.swing.JScrollPane'
java_import 'java.awt.Dimension'
java_import 'java.awt.Rectangle'
java_import 'java.awt.event.ComponentListener'

class AbstractBrupExtensionUI < JScrollPane
  include ITab
  include ComponentListener

  attr_reader :extensionName

  def initialize(name)
    @extensionName = name
    @panel = JPanel.new
    @panel.setLayout nil
    super(@panel)
    addComponentListener self
  end

  def add(component)
    bounds = component.getBounds
    updateSize(bounds.getX + bounds.getWidth, bounds.getY + bounds.getHeight)
    @panel.add component
  end

  alias_method :getTabCaption, :extensionName

  def getUiComponent
    self
  end

  def componentHidden(componentEvent); end

  def componentMoved(componentEvent); end

  def componentResized(componentEvent); end

  def componentShown(componentEvent);end

  def errorMessage(text)
    JOptionPane.showMessageDialog(self, text, 'Error', 0)
  end

  def message(text)
    JOptionPane.showMessageDialog(self, text)
  end

  private
  #Don't set the size smaller than existing widget positions
  def updateSize(x,y)
    x = (@panel.getWidth() > x) ? @panel.getWidth : x
    y = (@panel.getHeight() > y) ? @panel.getHeight : y
    @panel.setPreferredSize(Dimension.new(x,y))
  end

end

java_import('java.awt.Insets')
class AbstractBurpUIElement
  def initialize(parent, obj, positionX, positionY, width, height)
    @swingElement =obj
    setPosition parent, positionX, positionY, width, height
    parent.add @swingElement
  end

  def method_missing(method, *args, &block)
    @swingElement.send(method, *args)
  end

  private
  def setPosition(parent, x,y,width,height)
    insets = parent.getInsets
    size = @swingElement.getPreferredSize()
    w = (width > size.width) ? width : size.width
    h = (height > size.height) ? height : size.height
    @swingElement.setBounds(x + insets.left, y + insets.top, w, h)
  end
end

java_import 'javax.swing.JLabel'
class BLabel < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height, caption, align= :left)
    case align
    when :left
      a = 2
    when :right
      a = 4
    when :center
      a = 0
    else
      a = 2 #align left
    end
    super parent, JLabel.new(caption, a),positionX, positionY, width, height
  end
end

java_import 'javax.swing.JButton'
class BButton < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height, caption, &onClick)
    super parent, JButton.new(caption), positionX, positionY, width, height
    @swingElement.add_action_listener onClick
  end
end

java_import 'javax.swing.JSeparator'
class BHorizSeparator < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width)
    super parent, JSeparator.new(0), positionX, positionY, width, 1
  end
end

class BVertSeparator < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, height)
    super parent, JSeparator.new(1), positionX, positionY, 1, height
  end
end

java_import 'javax.swing.JCheckBox'
class BCheckBox < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height, caption)
    super parent, JCheckBox.new(caption), positionX, positionY, width, height
  end
end

java_import 'javax.swing.JTextField'
class BTextField < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height, caption)
    super parent, JTextField.new(caption), positionX, positionY, width, height
  end
end

java_import 'javax.swing.JComboBox'
class BComboBox < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height, &evt)
    super parent, JComboBox.new, positionX, positionY, width, height
    @swingElement.add_action_listener evt
  end

  def text
    getSelectedItem
  end

  def text=(v)
    removeAllItems
    addItem(v)
  end
end

java_import 'javax.swing.JTextArea'
class BTextArea < AbstractBurpUIElement
  def initialize(parent, positionX, positionY, width, height)
    @textArea = JTextArea.new
    super parent, @textArea, positionX, positionY, width, height
    @textArea.setLineWrap(true)
  end
end

java_import 'burp.ITextEditor'
class BTextEditor < AbstractBurpUIElement
  def initialize(parent, callbacks, positionX, positionY, width, height)
    @textArea = callbacks.createTextEditor
    super parent, @textArea.getComponent, positionX, positionY, width, height
  end

  def setText(text)
    @textArea.setText text.bytes
  end
  alias_method :text=, :setText

  def getText
    @textArea.getText.map {|b| b.chr}.join
  end
  alias_method :text, :getText

  def setEditable(bool)
    @textArea.setEditable bool
  end

  def getSelectedText
    @textArea.getSelectedText
  end

  def getSelectionBounds
    @textArea.getSelectionBounds
  end
end

#########################################################################################
#Begin Burp Extension
#########################################################################################

# Utilities
module BurpUtilities

  #Extened Ruby string for working inside burp
  module StringExtensions
    #Use the static methods on the IExtenhelper interface and add them to the string class to better fit ruby
    #string object model

    def self.included(base)
      base.send(:include,InstanceMethods)
      base.extend(StaticMethods)
    end

    module StaticMethods
      def extensionHelpers=(v)
        @@extensionHelpers = v
      end

      def extensionHelpers
        @@extensionHelpers
      end
    end

    module InstanceMethods

      def urlDecode
        self.class.extensionHelpers.urlDecode self
      end

      def urlEncode
        self.class.extensionHelpers.urlEncode self
      end

      def base64Decode
        String.from_java_bytes self.class.extensionHelpers.base64Decode(self)
      end

      def base64Encode
        self.class.extensionHelpers.base64Encode self
      end

      def to_HttpMessage(headers=[])
        self.class.extensionHelpers.buildHttpMessage(headers, self.to_java_bytes)
      end

    end
  end

  #assumes String extended by StringExtensions
  class OllamaAPI
    #a simple ring for keeping context
    class ContextBuffer
      def initialize(size)
        @max = size
        @buffer = []
      end

      def add(item)
        @buffer << item
        @buffer.shift if @buffer.length > @max
        item
      end

      def each
        @buffer.each {|i| yield i }
      end
    end

    def self.callbacks=(callbacks)
      @@callbacks = callbacks
    end

    def self.callbacks
      @@callbacks
    end

    def initialize(host = '127.0.0.1', port = 11434, is_https = false)
      @base_url_String = "http#{is_https ? 's':''}://#{host}:#{port}/api/"
      @http_service = String.extensionHelpers.buildHttpService(host, port.to_i, is_https)
      @context = ContextBuffer.new 6
      @lock = Mutex.new
    end

    attr_writer :system
    attr_writer :options

    def options
      @options ||= ''
    end

    def system
      @system ||= ''
    end

    def version
      new_http_message 'version'
    end

    def tags
      new_http_message 'tags'
    end
    alias_method :models, :tags

    def tag
      @tag ||= nil
      return @tag if @tag
      tags_rsp = tags
      raise RuntimeError 'No models present in Ollama' unless tags_rsp['models']
      @tag = tags['models'][0]['model']
    end

    def tag=(v)
      @tag = v
    end
    alias_method :model=, :tag=


    def generate(prompt)
      request = {}
      request["model"] = @tag
      request["prompt"] = prompt
      request["stream"] = false
      request["options"] = options if options != ''
      request["system"] = @system if system != ''
      request["raw"] = false
      new_http_message 'generate', 'POST', request.to_json
    end

    def chat(prompt)
      request = {}
      request["model"] = @tag
      request["stream"] = false
      request["options"] = options if options != ''
      request["raw"] = false
      request["messages"] = Array.new
      request["messages"] << {"role":"system", "content": @system} if system != ''
      #This will keep the chat history order, use multiple api instances for parallelism of chats
      response = nil
      @lock.synchronize do
        @context.each {|item| request["messages"] << item }
        request["messages"] << {"role":"user", "content":prompt}
        response = new_http_message 'chat', 'POST', request.to_json
        unless response['error']
          @context.add({"role":"user", "content":prompt})
          @context.add({"role":"assistant", "content": response['message']['content']})
        end
      end
      response
    end

    private
    #create and send new http message to send to the API
    def new_http_message(web_method, method='GET', body=nil)
      method.upcase!
      url = java.net.URL.new("#{@base_url_String}#{web_method}")
      message = String.extensionHelpers.buildHttpRequest url
      message = String.extensionHelpers.toggleRequestMethod(message) if %w[POST PUT PATCH].include? method
      info = String.extensionHelpers.analyzeRequest(@http_service, message)
      headers_jlist = info.getHeaders
      headers = []
      headers = headers_jlist.select {|header| header[0..6] != 'Accept:'}
      headers << 'Accept: application/json; charset=utf-8'
      headers << 'Content-Type: application/json' if body
      body ||= ''
      request  = String.extensionHelpers.buildHttpMessage(headers, body.to_java_bytes)
#lame debug
      puts "\n\n\n\n#{String.from_java_bytes request}"
      response = self.class.callbacks.makeHttpRequest(@http_service, request).getResponse
      info = String.extensionHelpers.analyzeResponse response
      JSON.parse String.from_java_bytes(response[(info.getBodyOffset)..-1])
    rescue => e
      { "error": e.message }
    end

  end
end

#payload processor
java_import 'burp.IIntruderPayloadProcessor'
class OllamaPaylaodProcessor
  include IIntruderPayloadProcessor

  def initialize(api, options)
    @options = options
    @api = api
  end

  def getProcessorName; 'Ollama Payload Processor'; end

  def processPayload(currentPayload, originalPayload, baseValue)
    payload = @options[:cb_json] ? json_unescape(currentPayload) : String.from_java_bytes(currentPayload)
    base = @options[:cb_json] ? json_unescape(baseValue) : String.from_java_bytes(baseValue)

    payload = [@options[:prompt_prefix], payload, @options[:prompt_suffix]].join ' '
    payload = [payload, @options[:context_prefix], base, @options[:context_suffix]].join(' ') if @options[:cb_context]

    response = (@options[:cb_chat] ? @api.chat(payload) : @api.generate(payload))
    return response['error'].to_java_bytes if response['error']
    @options[:cb_chat] ? response['message']['content'].to_java_bytes : response['response'].to_java_bytes
  end

  private
  #these are probably the actual subs anyone would want here
  def json_unescape(json_string, retried = false)
    target = String.from_java_bytes json_string
    target.gsub! '\n', "\n"
    target.gsub! '\\', "\\"
    target.gsub! '\r', ''
    target.gsub! '\t', "\t"
    target.gsub! '\"', "\""
    target
  end
end

# User interface
class MainTab < AbstractBrupExtensionUI
  def initialize(extension, callbacks)
    @payload_processor = nil
    @api = nil
    @callbacks = callbacks
    super extension
    buildUI
  end

  def componentResized(evt)
    onResize
  end

  def buildUI
    @textEntries = {}; @checkBoxes = {}
    BLabel.new(self, 2, 2, 50, 30, 'Ollama Options:')
    BLabel.new(self, 2,30,50, 30, 'Host:')
    @textEntries[:host] = BTextField.new(self, 52, 30, 100, 30, 'localhost')
    BLabel.new(self,2,60,50,30, 'Port:')
    @textEntries[:port] = BTextField.new(self, 52, 60, 100, 30, '11434')
    @checkBoxes[:cb_https] = BCheckBox.new(self, 2,90,50,30, "Use HTTPS?")
    BButton.new(self, 200, 90, 150, 30, 'Connect!') {|evt| onConnect}
    BLabel.new(self, 2,120, 150,20, 'Payload Options:')
    BLabel.new(self, 2,150,50,30, 'Model:')
    @textEntries[:model_list] = BComboBox.new(self, 52,150, 50, 30) {|evt| onModelSel}
    BLabel.new(self, 2,170,50,30, 'System Prompt:')
    @textEntries[:system] = BTextEditor.new( self, @callbacks, 2, 200,50,120)
    @checkBoxes[:cb_json] = BCheckBox.new(self, 2,320,300,30, "JSON unescape current/base responses?")
    @checkBoxes[:cb_chat] = BCheckBox.new(self, 300, 320, 150, 30, 'Use Running Chat?')
    @checkBoxes[:cb_context] = BCheckBox.new(self, 450, 320, 300,30, 'Include Context (baseValue)?')
    BLabel.new(self, 2, 350, 50, 30, 'Prompt Prefix:')
    BLabel.new(self, 2, 380, 50, 30, 'Prompt Suffix:')
    BLabel.new(self, 2, 410, 50, 30, 'Context Prefix:')
    BLabel.new(self, 2, 440, 50, 30, 'Context Suffix:')
    @textEntries[:prompt_prefix] = BTextField.new( self, 102, 350,50,30, '')
    @textEntries[:prompt_suffix] = BTextField.new( self, 102, 380,50,30,'')
    @textEntries[:context_prefix] = BTextField.new( self, 102, 410,50,30,'')
    @textEntries[:context_suffix] = BTextField.new( self, 102, 440,50,30,'')
    BButton.new(self,2,470, 100,30, 'Configure Processor') {|evt| onConfigure}
    onResize
    restore_options
  end

  def onResize
    bounds = self.getBounds
      w = bounds.getWidth - 114
      @textEntries.each do |name, obj|
        rect = obj.getBounds
        h = rect.getHeight
        rect.setSize(w,h)
        obj.setBounds(rect)
    end
  end

  #To make passing value of ui around easy
  def options
    options = Hash.new
    @textEntries.each {|k,v| options[k] = v.text }
    @checkBoxes.each {|k,v| options[k] = v.isSelected }
    options
  end

  def options_from_hash(options)
    @textEntries.each_key {|k| @textEntries[k].text = (options[k] ||= '') }
    @checkBoxes.each_key {|k| @checkBoxes[k].setSelected(true) if options[k] }
  end

  def onConnect
    @api = BurpUtilities::OllamaAPI.new(@textEntries[:host].text, @textEntries[:port].text, @checkBoxes[:cb_https].isSelected)
    tags = nil
    t = Thread.new { tags = @api.tags } ; t.join #HACK TO deal with burp UI rules
    return unless tags['models']
    @textEntries[:model_list].removeAllItems
    tags['models'].each { |rec| puts rec['model']; @textEntries[:model_list].addItem rec['model'] }
  rescue
    nil
  end

  def onModelSel

  end

  def onConfigure
    @api.tag = @textEntries[:model_list].getSelectedItem
    @api.system = @textEntries[:system].text
    payload_proc = OllamaPaylaodProcessor.new @api, options
    @callbacks.removeIntruderPayloadProcessor @payload_processor if @payload_processor
    @payload_processor = payload_proc
    @callbacks.registerIntruderPayloadProcessor @payload_processor
    save_options
  end

  private
  def save_options
    @callbacks.saveExtensionSetting(@extensionName, Base64.strict_encode64(Marshal.dump(options)))
  end

  def restore_options
    settings = @callbacks.loadExtensionSetting(@extensionName)
    return unless settings
    options = Marshal.load(Base64.strict_decode64(settings))
    options_from_hash options
    @api = BurpUtilities::OllamaAPI.new(@textEntries[:host].text, @textEntries[:port].text, @checkBoxes[:cb_https].isSelected)
  rescue
    callbacks.saveExtensionSetting(@extensionName, nil) #clear the value
  end
end


#Burp Extender Interface
java_import 'burp.IExtensionHelpers'
java_import 'burp.IBurpExtender'
require 'JSON'
require 'Base64'
class BurpExtender
  include IBurpExtender
  ExtensionName = File.basename(__FILE__)[0..-4]

  def registerExtenderCallbacks(callbacks)

    ###DEBUG
    #require 'pry'
    #require 'pry-nav'
    ###END

    String.include BurpUtilities::StringExtensions
    String.extensionHelpers = callbacks.getHelpers
    BurpUtilities::OllamaAPI.callbacks = callbacks
    callbacks.addSuiteTab MainTab.new(ExtensionName, callbacks)
  end
end