// Simple tabbing functionality

// activate(ele)
//
// Called by tab's onclick handler, activates the tab and
// corresponding content box.

var activate = function(ele) {
  if (!ele) {
    return;
  }
  
  var index = -1,
      clicked_index = -1,
      children = ele.parentNode.parentNode.childNodes;
  
  for(var i in children) {
    if (has_class(children[i], "tabbar")) {
      var tabs = children[i].childNodes;
      
      // Tabs
      for(var j in tabs) {
        if(has_class(tabs[j], "tab")) {
          index += 1;
          
          if(tabs[j] == ele) {
            clicked_index = index;
            tabs[j].className = "tab active";
          } else {
            tabs[j].className = "tab inactive";
          }
        }
      }
    }
  }
      
      
  // Boxes    
  if(ele.parentNode && ele.parentNode.parentNode) {
    var children = ele.parentNode.parentNode.childNodes;
    
    var box_index = -1;
        index = -1;
    
    for(var i in children) {
      if(has_class(children[i], "box")) {
        index += 1;
                      
        if(index == clicked_index) {
          children[i].className = "box active";
        } else {
          children[i].className = "box inactive";
        }
      }
    }
  }
}

// select_by_class(class_name)
//
// Selects all documents with class class_name.
var select_by_class = function(class_name) {
  var all = document.getElementsByTagName('*'), 
        i,
        elements = [];
    
  for (i in all) {
    if(has_class(all[i], class_name)) {
      elements.push(all[i]);
    }
  }
  
  return elements;
}

// has_class(ele, class_name)
//
// Determines whether the given element ele has the class
// name class_name;
var has_class = function(ele, class_name) {
  if(ele) {
    return (' ' + ele.className + ' ').indexOf(' ' + class_name + ' ') > -1
  }
}
;
