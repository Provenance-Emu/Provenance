class AppDelegate
  def application(application, didFinishLaunchingWithOptions:launchOptions)
  	realm = RLMRealm.defaultRealm
    
    realm.beginWriteTransaction
    
    obj = RubyMotionRealmObject.new
    obj.boolProp = true
    obj.intProp = 123
    obj.floatProp = 123.45
    obj.doubleProp = 234.56
    obj.stringProp = "abcd"
    obj.binaryProp = "abcd".dataUsingEncoding(NSUTF8StringEncoding)
    obj.dateProp = NSDate.date
    obj.cBoolProp = true
    obj.longProp = 123456

    # Object properties are supported
    stringObj = StringObject.new
    stringObj.stringProp = "xyz"
    obj.objectProp = stringObj

    # Array properties are not yet supported in RubyMotion
    # obj.arrayProp.addObject(stringObj)

    realm.addObject(obj)
    
    realm.commitWriteTransaction

    puts RubyMotionRealmObject.allObjects.description
    
    true
  end
end
