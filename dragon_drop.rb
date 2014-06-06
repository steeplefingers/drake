# DESCRIPTION: script that take the current page's html and figures out how to make a set of watir-webdriver functions for you. 

# TODO  make templates for a class that can be generated. include the function generation but put in
#       the list of xpaths that you found. 
# TODO  make the class files and put them in the dragon_drop directory. 

#gem "test-unit"
require "rubygems"
require 'fox16'
require 'nokogiri' # used for getting the xml of a webpage and searching it for xpaths. 
#require "test/unit" # this is used so we can get a default call to setup/teardown at the beginning/end of a test. helps with cleanup. 
require "open-uri"
require "watir-webdriver"
require 'rexml/document'

#include REXML
include Fox

$dragon_drop_debug = true
$element_types = ["input", "button", "radio", "checkbox", "text_field", "select_list", "label", "span", "link", "image", "li", "h1", "h2", "h3", "h4", "h5", "h6"]
#$element_types = ["link"]
$element_index = 0
$elements = []
$style_highlight = "outline:4px solid purple;"
$style_mapped = "outline:2px solid green;"

$xpath_to_name = {}
$name_to_xpath = {}

# TODO remove any dependency on test-unit stuff--it's not a "test", it's a script. 
#class Test_Case < Test::Unit::TestCase

  # # teardown is run after every test
  # def teardown
  #   $b.close
  #   log("**************************** Closing browser session ****************************")
  # end

  def print_name_to_xpath
    # print out what the dictionary would look like if you were to 
    # use it in some code, so the user can copy-paste at any time. 

    puts "xpaths = {"
    $name_to_xpath.each do |key, value|
        puts "   '#{key}' => '#{value}',"
    end
    puts "}"
  end

  def transform_xpath_to_name
    # go through each key/value pair and store 
  end

  def open_browser
    if $b == nil
        log("**************************** Opening browser session ****************************")
        client = Selenium::WebDriver::Remote::Http::Default.new
        client.timeout = 600
        $timeout_length = 30

        firepath_path = nil
        firebug_path = nil
        # Find.find(ENV['APPDATA'] + "/Mozilla/Firefox/Profiles") do |path|
        #     firepath_path = path if path =~ /.*FireXPath.*.xpi/
        #     firebug_path = path if path =~ /.*firebug.*.xpi/
        # end

        # # if firepath_path isn't populated, tell the user that they need it. 
        # if firepath_path == nil or firebug_path == nil
        #     log("You can use Firepath within Firefox, but need both Firebug and Firepath installed. It's a helpful tool for troubleshooting later.")
        #     $b = Watir::Browser.new :ff, :http_client => client
        # else
        #     log("Firebug location is #{firebug_path}")
        #     log("Firepath location is #{firepath_path}")
        #     debug_profile = Selenium::WebDriver::Firefox::Profile.new
        #     debug_profile.add_extension firepath_path
        #     debug_profile.add_extension firebug_path
        #     $b = Watir::Browser.new :ff, :http_client => client, :profile => debug_profile            
        # end
        $b = Watir::Browser.new :chrome

    end

  end

  def go_to_url(url)
    if $b == nil
        open_browser
    end
    log("Go to #{url}")
    load_link($timeout_length){ $b.goto url }
  end
  
  def load_link(waittime)
    begin
      Timeout::timeout(waittime)  do
    yield
    end
    rescue Timeout::Error => e
      log("Page load timed out: #{e}")
    retry
    end
  end

  def xpath_mapped?(xpath)
    return $xpath_to_name.has_key?(xpath)
  end

    def get_all_xpaths_on_page
        $xpaths = []
        $doc = Nokogiri::HTML($b.html)
        
        $element_types.each do |type|
            log("Searching for elements of type <#{type}>")
            $doc.xpath("//#{type}").each do |xpath|
                log("   Found xpath: #{xpath}")
                type_no_slashes = type.sub(/^[\/]*/, "").sub(/\[.*\]/, "")

                k = xpath.keys
                v = xpath.values
                x = k.zip(v).map {|kx, vx| "@#{kx}=\"#{vx}\""}
                x = x.join(' and ')
                x.gsub!("/", "\/")
                #f =  "//" + xpath.ancestors.reverse.map{ |node| node.name }[-2..-1].join('/') + "/" + type_no_slashes + "[" + x + "]"
                if x != "" 
                    f =  "//" + xpath.ancestors.reverse.map{ |node| node.name }[-2..-1].join('/') + "/" + type + "[" + x + "]"
                else 
                    f =  "//" + xpath.ancestors.reverse.map{ |node| node.name }[-2..-1].join('/') + "/" + type
                end
                # SPECIAL CASE: this will result in an xpath beginning with //
                # if there's an html in there it might result in //html, which won't find a match. 
                # replace /html/ with //
                f.gsub!("/html/", "/")

                log("   xpath after mods: #{f}")
                if not $b.element(:xpath => f).visible?
                    log ("   > not visible--skipping")
                else
                    $xpaths.push(f)
                end

                highlight_element(f)
                sleep(1)
                unhighlight_element(f)

            end
        end
    end

    def log(msg)
        # get today's date 
        time = Time.new
        logfile = File.expand_path(time.strftime('%Y%m%d') + ".log")
        File.open(logfile, 'a') { |file| file.write(time.strftime('%H:%M:%S') + " - " + msg + "\n") }
    end

  def get_number_of_xpath_hits(xpath)
    return $b.elements(:xpath => xpath).size
  end

  def get_minimum_functional_xpath(xpath)
    original_xpath = xpath 
    return xpath
  end

  def highlight_element(xpath)
    # get the xpath for the current element index
    if $b != nil
        #$b.element(:xpath => xpath).when_present.focus
        $b.execute_script("
            var element = document.evaluate('#{xpath}', document, null, XPathResult.ANY_UNORDERED_NODE_TYPE, null ).singleNodeValue;
            if (element != null) 
            { 
                element.setAttribute('style', '#{$style_highlight}') 
            }
        ")
    end
  end

  def unhighlight_element(xpath)
    if $b != nil
        # find the element by xpath, and use a regex to remove the purple outline style from the element's current style. 
        # then set the attribute to the new style
        $b.execute_script("
            var element = document.evaluate('#{xpath}', document, null, XPathResult.ANY_UNORDERED_NODE_TYPE, null ).singleNodeValue;
            if (element != null) 
            { 
                var style = element.getAttribute('style')
                var re = '#{$style_highlight}'
                var new_style = style.replace(re, '');
                element.setAttribute('style', new_style) 
            }
        ")
    end
  end

  #def test_case

    # every time an element is mapped, dump the block of code to a text box or something. 
    # comment to the user, whenever they're done, to copy/paste that code into the target class. 
    # the code should contain the xpaths dictionary, with the name mapped to the xpath to use. 
    # may need to figure how to create a new dictionary with name => xpath instead of xpath => name. 

    # start by opening the browser. guaranteed that the user's gonna want it if they're running this. 
    #open_browser

    # create the app and window instance
    app = FXApp.new
    main_window = FXMainWindow.new(app, "Dragon Drop", :width => 250, :height => 250)

    # # setup the groupboxes for controls to go into
    # groupbox_elements = FXGroupBox.new(main_window, "Elements/Navigation", GROUPBOX_TITLE_CENTER|FRAME_RIDGE)
    # groupbox_xpath = FXGroupBox.new(main_window, "XPathElements/Navigation", GROUPBOX_TITLE_CENTER|FRAME_RIDGE)
    # groupbox_browser = FXGroupBox.new(main_window, "Browser/URL", GROUPBOX_TITLE_CENTER|FRAME_RIDGE)
    # groupbox_code = FXGroupBox.new(main_window, "Generated Code", GROUPBOX_TITLE_CENTER|FRAME_RIDGE)

    # # add the controls to the appropriate groupboxes upon creation
    # button_find_elements = FXButton.new(groupbox_elements, "Find All on Page", :x => 0)
    # button_previous_element = FXButton.new(groupbox_elements, "< Prev", :x => 100)
    # button_next_element = FXButton.new(groupbox_elements, "Next >", :x => 200)
    # #button_open_browser = FXButton.new(groupbox_browser, "Open Browser")
    # textfield_url = FXTextField.new(groupbox_browser, 30)
    # textfield_code = FXText.new(groupbox_code, :width => 500, :height => 250, :opts => LAYOUT_FIX_WIDTH|TEXT_READONLY)
    # textfield_element_name = FXTextField.new(groupbox_xpath, 50, :width => 50)
    # textfield_element_xpath = FXTextField.new(groupbox_xpath, 50, :width => 50)
    # textfield_xpath_root = FXTextField.new(groupbox_xpath, 50)

    # # connect the controls to the functions
    # button_find_elements.connect(SEL_COMMAND) { get_all_xpaths_on_page }
    # button_previous_element.connect(SEL_COMMAND) { unhighlight_element; $element_index -= 1; highlight_element }
    # button_next_element.connect(SEL_COMMAND) { unhighlight_element; $element_index += 1; highlight_element }
    # #button_open_browser.connect(SEL_COMMAND) { open_browser }
    # textfield_url.connect(SEL_COMMAND) { go_to_url(textfield_url.text) }


    contents = FXHorizontalFrame.new(main_window, LAYOUT_SIDE_TOP|FRAME_NONE|LAYOUT_FILL_X|LAYOUT_FILL_Y|PACK_UNIFORM_WIDTH)
    tabbook = FXTabBook.new(contents,:opts => TABBOOK_LEFTTABS|LAYOUT_FILL_X|LAYOUT_FILL_Y|LAYOUT_RIGHT)
    tab1 = FXTabItem.new(tabbook, "Simple List", nil)
    listframe = FXHorizontalFrame.new(tabbook, FRAME_THICK|FRAME_RAISED)
    simplelist = FXList.new(listframe, :opts => LIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    simplelist.appendItem("First Entry")
    simplelist.appendItem("Second Entry")
    simplelist.appendItem("Third Entry")
    simplelist.appendItem("Fourth Entry")
      
    # Second item is a file list
    tab2 = FXTabItem.new(tabbook, "File List", nil)
    fileframe = FXHorizontalFrame.new(tabbook, FRAME_THICK|FRAME_RAISED)
    filelist = FXFileList.new(fileframe, :opts => ICONLIST_EXTENDEDSELECT|LAYOUT_FILL_X|LAYOUT_FILL_Y)
    
    # Third item is a directory list
    tab3 = FXTabItem.new(tabbook, "Tree List", nil)
    dirframe = FXHorizontalFrame.new(tabbook, FRAME_THICK|FRAME_RAISED)
    dirlist = FXDirList.new(dirframe, :opts => DIRLIST_SHOWFILES|TREELIST_SHOWS_LINES|TREELIST_SHOWS_BOXES|LAYOUT_FILL_X|LAYOUT_FILL_Y)

    # put some stuff in the code window
    #textfield_code.text = "asdfl;j\nasdl;fjkasf\na;sdlfkjasdf;\nasdkofjasl;dfj\n ;alsdjfl;asfasl;fj\nal;sdkfjasl;f\nasfjasl;fj"

    # create the app and go into a loop to run it.
    app.create
    main_window.show(PLACEMENT_SCREEN)
    app.run

    abort("debug stop @ line #{__LINE__}")



    go_to_url("www.slashmail.org")
    get_all_xpaths_on_page
    $xpaths.each do |xpath|
        # find out how 
        log("#{get_number_of_xpath_hits(xpath)} hit(s)")
        highlight_element(xpath)
        #sleep(1)
        unhighlight_element(xpath)
    end
    abort("debug stop @ line #{__LINE__}")






    # # this is the "main loop" for the app
    # # events are triggered from interacting with different elements in the app. 
    # app = FXApp.new
    # main_window = FXMainWindow.new(app, "Function Creator", :width => 640, :height => 480)
    # sites = FXComboBox.new(main_window, 50)
    # for site in ["Choose a site:", "qa-x1.intelispend.com", "qa.myprepaidcenter.com"]
    #     sites.appendItem(site)
    # end
    # # connect a function to the SEL_COMMAND to go to the chosen site
    # sites.connect(SEL_COMMAND) do |sender, sel, index| 
    #     go_to_url(sender.text)
    # end

    # # set up the "scrape" button
    # button_find_elements = FXButton.new(main_window, "Find Elements", :width => 75, :height => 30)

    # # set up a list box for different xpaths that are found on the current page
    # $xpath_listbox = FXListBox.new(main_window, :width => 75)
    # $xpath_listbox.numVisible = 6

    
    # # set up a textarea for the proposed function once selected from $xpath_listbox and
    # # combined with whatever options user selected underneath. 
    # #$function_textfield = FXTextField.new(main_window, 
    #     #:width => 100, :height => 100)


    # # textfield_url = FXTextField.new(main_window, 25)
    # # textfield_xpath_tester = FXTextField.new(main_window, 25)
    # # button_find_elements = FXButton.new(main_window, "Find Elements", :width => 75, :height => 30)
    
    # # #button_find_elements.connect(SEL_COMMAND) { find_elements }
    # # button_find_elements.connect(SEL_COMMAND) { parse_html }

    # app.create
    # main_window.show(PLACEMENT_SCREEN)
    # app.run

    #go_to_url "qa-x1.intelispend.com"
    #go_to_url "http://www.w3schools.com/html/html_forms.asp"
    #go_to_url "fentonqa-my.intelispend.com"
    # go_to_url "qa-x1.intelispend.com"
    # $b.text_field(:xpath => '//input[@id="user_username"]').when_present.set("mfritzius")
    # $b.text_field(:xpath => '//input[@id="user_password"]').when_present.set("y@b@waz33!1")
    # $b.element(:xpath => '//span[text()="LOGIN"]').when_present.click
    # $b.element(:xpath => '//h1[text()="Welcome to X-One"]').wait_until_present
    # go_to_url "https://qa-x1.intelispend.com/merchants/search"
    # go_to_url "www.slashmail.org"
    #sleep(2)
    # # take the current page's html and make sure that only one tag's worth of data is on one line. 
    # html = $b.html
    # #html.gsub!(/(<\/[^>]*>)[^<]*(<)/, "\1\n\2")
    # $doc = Nokogiri::HTML(html)
    #get_all_elements

    # get into a holding pattern, waiting for user to start clickin thangs

    # find all text fields for the current screen


    # twerks
    # find all text_fields for the current screen
    #$doc.xpath('//input[@type="text"]').each do |item|




 #   xpath = "//input[@type='text' and @placeholder='Username' and @name='login_view_model[username]' and @id='login_view_model_username' and @display_name='false' and @class='form-control input-lg']"
#    puts "xpath[1]: #{xpath}"
    # this works, don't mess with it
    # $b.execute_script(
    #     "var element = document.evaluate(\"#{xpath}\", document, null, XPathResult.FIRST_ORDERED_NODE_TYPE, null ).singleNodeValue;
    #     if (element != null) { element.setAttribute('style', 'border:2px dotted purple;') }")


    # sleep(3)
    # abort("stop--just messing with adding style to an element")

    #$doc.xpath("//input[@placeholder='Username']").each do |item|
    #$doc.xpath("//span[@type!='hidden']").each do |item|
    #$doc.xpath('//input[@type="text"]').each do |item|
    #$doc.xpath('//span[text()="CONTINUE"]').each do |item|
    # the below line works--use as an example
    #$doc.xpath('//span').each do |item|

#     # THIS STUFF WORKS - use fxruby to do this though
#     $element_index = 0
#     $elements.each do |element|
#         puts "element is #{element}" if $dragon_drop_debug
#         # item = $doc.xpath(element)
#         # puts "item is #{item}" if $dragon_drop_debug
#         # DEBUG print the parent
#         #puts "item:"
#         #puts item
#         # puts "item.parent:"
#         # puts item.parent
#         # puts "item.parent.parent:"
#         # puts item.parent.parent
#         # #puts "item:          " + item
#         #xpath = xml_to_xpath(item)
#         xpath = xml_to_xpath(element)
#         puts "xpath is #{xpath}" if $dragon_drop_debug

#         number_of_xpath_hits = get_number_of_xpath_hits(xpath)
#         if number_of_xpath_hits == 0
#             puts " * ERROR: xpath #{xpath} got 0 hits! check parsing and try again."
#             next
#         else
#             puts "number of hits for xpath is #{get_number_of_xpath_hits(xpath)}" if $dragon_drop_debug
# #        puts "xpath[2]: " + xpath

#         # put an outline around this item
#         # start by getting the style, if there is one
#         #if $b.element(:xpath => xpath).visible?
#             $b.element(:xpath => xpath).focus
#             add_outline(xpath)
#             #sleep(1)
#             remove_outline(xpath)

#         #end

#         #add_outline(xpath)
#         #sleep(1)
#         #remove_outline(xpath)
#         #sleep(1)


#     end
#     $stdout.flush
#     end

    #abort("debug stop--messing with nokogiri for now")

    # create the app and window instance
    app = FXApp.new
    main_window = FXMainWindow.new(app, "Dragon Drop", :width => 640, :height => 480)
    textfield_url = FXTextField.new(main_window, 25)

    # create the labels
    url_label = FXLabel.new(main_window, text="Enter the URL to go to:", :x => 200, :y => 200)
    navigation_labels = FXLabel.new(main_window, text="Elements", :x => 200, :y => 300)

    # create the buttons
    button_find_elements = FXButton.new(main_window, "Find Elements", :width => 75, :height => 30)
    button_previous_element = FXButton.new(main_window, "< Previous Element", :width => 25, :height => 30, :y => 100)
    button_next_element = FXButton.new(main_window, "Next Element >", :width => 25, :height => 30, :y => 100)
    button_open_browser = FXButton.new(main_window, "Open Browser", :x => 0, :y => 200)

    # connect the buttons to functions
    button_find_elements.connect(SEL_COMMAND) { get_all_elements_on_page }
    button_previous_element.connect(SEL_COMMAND) { unhighlight_element; $element_index -= 1; highlight_element }
    button_next_element.connect(SEL_COMMAND) { unhighlight_element; $element_index += 1; highlight_element }
    button_open_browser.connect(SEL_COMMAND) { open_browser }
    
    # create the text fields
    textfield_url = FXTextField.new(main_window, 25)
    textfield_custom_xpath = FXTextField.new(main_window, 25)

    # connect the text fields to functions
    textfield_url.connect(SEL_COMMAND) { go_to_url(textfield_url.text) }
    textfield_xpath_tester.connect(SEL_COMMAND) { xpath_test(textfield_xpath_tester.text) }

    app.create
    main_window.show(PLACEMENT_SCREEN)
    app.run


  # end
# end
