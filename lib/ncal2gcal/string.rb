# 
class String
  def asciify()
    str = self
    # ----------------------------------------------------------------
    # Umlauts
    # ----------------------------------------------------------------
    str = str.gsub(/\334/,"Ãœ")  # Ü
    str = str.gsub(/\374/,"Ã¼") # ü
    str = str.gsub(/\326/,"Ã–") # Ö
    str = str.gsub(/\366/,"Ã¶") # ö
    str = str.gsub(/\304/,"Ã„") # Ä
    str = str.gsub(/\344/,"Ã¤")  # ä
    str = str.gsub(/\337/,"ÃŸ") # ß
    str = str.gsub(/>/,"&gt;")
    str = str.gsub(/</,"&lt;")
    # bez_neu = Iconv.conv('UTF-8','CP850', bez_neu)
    #str = str.gsub(/([^\d\w\s\.\[\]-])/, '')
    return str
  end 
end 
