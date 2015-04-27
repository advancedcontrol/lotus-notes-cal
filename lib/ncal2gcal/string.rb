# 
class String
  def asciify()
    str = self
    # ----------------------------------------------------------------
    # Umlauts
    # ----------------------------------------------------------------
    str = str.gsub(/\334/,"Ü")  # �
    str = str.gsub(/\374/,"ü") # �
    str = str.gsub(/\326/,"Ö") # �
    str = str.gsub(/\366/,"ö") # �
    str = str.gsub(/\304/,"Ä") # �
    str = str.gsub(/\344/,"ä")  # �
    str = str.gsub(/\337/,"ß") # �
    str = str.gsub(/>/,"&gt;")
    str = str.gsub(/</,"&lt;")
    # bez_neu = Iconv.conv('UTF-8','CP850', bez_neu)
    #str = str.gsub(/([^\d\w\s\.\[\]-])/, '')
    return str
  end 
end 
