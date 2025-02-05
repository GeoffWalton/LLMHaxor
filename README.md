What:

This is what I consider the minimum viable product for bolting an LLM models (running on Ollama) to Burps' Intruder. 

Projects like PyRIT and PyRITShip are probably the way to go if you are doing anything high tech! 

The idea here is to be able to quickly try targeting something with an LLM model whithout having to write any code and without having to use anything but local resources. Given compute requirements of LLMs it maybe valuable for getting an attack or experiment started while you work on scafolding a more serious attempt in PyRIT or othe tools.

How:

Load the LLMHaxor.rb into your Burp Extentder. (See Requirements)
Configure the output settings in Extender, requests to Ollama are printed for history
Goto the LLMHaxor tab and configure the host and port values for your Ollama 
Click 'Connect!' if that worked you should see the Model combo box populated with your public models 
Select a model
Enter a system prompt - This is likely where most of your 'attack payload will go' 
Optional: Enable the options you want, JSON unescape (\n -> literal newline, \t -> literal tab) these are applied to the base payload and current payload before being send to the model. If your target application is responding with JSON strings you may want this otherwise the escapes will themselves be escaped before being sent to the model
Optional: Enable Use Running Chat, if you want to provide the LLM with context of the previous prompt and replies (currently last 6)
Optional: Enable Include Context, will include the string "#{Context Prefix}#{basepayload}#{Context Suffix}" at the end of your prompt. 
Prompt Prefix: The prefix string to place before currentpayload
Prompt Suffix: The postfix for the current payload string
Optional: Context Prefix
Optional: Context Suffix
Click Configure Processor - This saves and registers the current paylaod process, click it again anytime you make changes or after restarting Burp 
Goto your intruder attack select your payload positions, and type (recursive grep likely), add a payload processor (invoke Burp extenstion) select Ollama Payload Processor 
 :-) cross fingers 

Requirements:

Ollam running somewhere reachable by Burp and some models configured.
Tested with jruby 9.3.8.0 (Should work with newer and possibly older Ruby jars) 
required additional gems: json, base64 
Ensure the path Burp Suite gets includes the JRUBY_LIB and JRUBY_HOME enviornment variables 
