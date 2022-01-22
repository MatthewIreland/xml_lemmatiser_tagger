import os

import betacode.conv
import urllib.request
import re
import sys
import time
import xml.etree.ElementTree as ET


AnalysisCache = {}  
#stores the output from Perseus (i.e. POS tag, morphological tags, lemma) when we look up a word; thus, when we see the same word form again, we do not have to
#go back to Perseus, which reduces the load on Perseus and speeds up the process (this is only at document level, word forms are not shared across documents)

class PerseusAnalysis:
    def __init__(self, greek_word): 
        #the init function creates variables that store the tags and the greek word forms (in order to use them further down)
        self.__greek_word_betacode = greek_word

        if greek_word in AnalysisCache:
            return

        self.__possible_pos_tags = [
            "adj",
            "adv",
            "article",
            "conj",
            "enclitic",
            "exclam",
            "indeclform",
            "noun",
            "numeral",
            "partic",
            "prep",
            "proclitic",
            "pron",
            "verb",
        ]

        self.__possible_verbal_morph_tags = [
            "1st",
            "2nd",
            "3rd",
            "act",
            "aor",
            "fut",
            "futperf",
            "imperat",
            "imperf",
            "ind",
            "inf",
            "mid",
            "mp",
            "opt",
            "part",
            "pass",
            "perf",
            "plup",
            "pres",
            "pres_",
            "subj",
        ]

        self.__possible_nominal_morph_tags = [
            "comp?",
            "comp_only?",
            "dat",
            "dual",
            "fem",
            "gen",
            "irreg_comp",
            "irreg_superl",
            "masc",
            "neut",
            "nom",
            "pl",
            "sg",
            "superl",
            "voc",
        ]

        self.__get_perseus_analysis(greek_word) #this function looks up a Greek word form on Perseus and uses the variables defined above regarding POS tags, etc. 



    def __get_perseus_analysis(self, greek_word):
        greek_word_encoded = urllib.parse.quote_plus(greek_word) #rewrites some of the betacode in order to be able to paste it into a webaddress
        unicode_greek_word = betacode.conv.beta_to_uni(greek_word) #convert betacode into unicode 

        try:
            file = urllib.request.urlopen(f"https://www.perseus.tufts.edu/hopper/morph?l={greek_word_encoded}&la=greek") #looks up word forms on the Perseus website
            data = file.read().decode("utf=8") #stores the webpage showing the analysis of a word form on Perseus 
            file.close()
        except Exception: #deal with the situation when the lookup fails
            try:
                sys.stderr.write(f"Error looking up {greek_word_encoded}. Retrying...\n")
                time.sleep(60)
                file = urllib.request.urlopen(f"https://www.perseus.tufts.edu/hopper/morph?l={greek_word_encoded}&la=greek")
                data = file.read().decode("utf=8")
                file.close()
            except Exception as e:
                sys.stderr.write(f"Retry failed.\n")
                raise e


        matches = re.findall('<td class="greek">(.*)</td>.*\n.*<td>(.*)</td>', data) #extracts the lemmata and tags from the webpage

        lemmata = []
        pos_tags = []
        verbal_morph_tags = []
        nominal_morph_tags = []

        num_pos_tags = 0 
        for match in matches:
            for tag in match[1].split(" "): #split up tags by means of the space character 
                # special case for "part" which implies pos tag is a verb (part stands for participle and participles are not given a POS tag on Perseus)
                if tag == "part":
                    pos_tags.append("verb")
                    num_pos_tags += 1

                if tag in self.__possible_pos_tags: #we check against the list of POS tags set out above
                    pos_tags.append(tag)
                    num_pos_tags += 1
                if tag in self.__possible_verbal_morph_tags: #we check against the list of verbal morphology tags set out above
                    verbal_morph_tags.append(tag)
                if tag in self.__possible_nominal_morph_tags: #we check against the list of nominal morphology tags set out above
                    nominal_morph_tags.append(tag)

        if num_pos_tags == 0:
            with open('errors.txt', 'a') as f:
                if self.__should_log_error(greek_word): #does not log capital letters and numbers as errors in the error.txt file
                    f.write(f"{greek_word}    {unicode_greek_word}    can't find pos tags\n") #creates the error.txt file 


        matches = re.findall('<h4 class="greek">(.*)</h4>', data)

        num_lemmata = 0 #do the same as above for the morphological tags for the lemmata
        if len(matches) > 1:
            for match in matches:
                # remove any lemmata ending in a digit, e.g. ἔχω2, καί3 (unless only one lemma)
                if not match[-1].isdigit():
                    lemmata.append(match)
                    num_lemmata += 1
        else:
            for match in matches:
                lemmata.append(match)
                num_lemmata += 1

        if num_lemmata == 0:
            with open('errors.txt', 'a') as f:
                if self.__should_log_error(greek_word):
                    f.write(f"{greek_word}    {unicode_greek_word}    can't find lemma\n")

        #creates labels for the tags of the word forms that cannot be parsed by Perseus
        #this is also relevant to nouns not having verbal morphology tags and verbs not having nominal morphology tags
        if len(lemmata) == 0:
            lemmata = ["NO_LEMMA"]

        if len(pos_tags) == 0:
            pos_tags = ["NO_POS"]

        if len(verbal_morph_tags) == 0:
            verbal_morph_tags = ["NO_VERBAL_MORPHOLOGY"]

        if len(nominal_morph_tags) == 0:
            nominal_morph_tags = ["NO_NOMINAL_MORPHOLOGY"]

        #we create new variables that store the de-duplicated tags (as Perseus may offer several parsings for the same word form 
        #which all display e.g. the same POS tag)
        self.__lemmata = list(set(lemmata))
        self.__pos_tags = list(set(pos_tags))
        self.__verbal_morphology = list(set(verbal_morph_tags))
        self.__nominal_morphology = list(set(nominal_morph_tags))


    def get_pos_tags(self):
        return self.__pos_tags

    def get_lemmata(self):
        return self.__lemmata

    def get_verbal_morphology(self):
        return self.__verbal_morphology

    def get_nominal_morphology(self):
        return self.__nominal_morphology


    def get_tab_separated_vertical_format(self): #creates a row in the vertical table
        if self.__greek_word_betacode in AnalysisCache:
            return AnalysisCache[self.__greek_word_betacode]

        greek_word = betacode.conv.beta_to_uni(self.__greek_word_betacode)
        lemmata = ";".join(self.get_lemmata()) #separate all the lemmata found for a word form by means of semicolon
        pos_tags = ";".join(self.get_pos_tags()) #separate all the POS tags found for a word form by means of semicolon
        verbal_morph_tags = ";".join(self.get_nominal_morphology()) #separate all the verbal morphology tags found for a word form by means of semicolon
        nominal_morph_tags = ";".join(self.get_verbal_morphology()) #separate all the nominal morphology tags found for a word form by means of semicolon

        tab_separated_string = "\t".join([greek_word, pos_tags, lemmata, verbal_morph_tags, nominal_morph_tags]) #create one row for each word form found

        AnalysisCache[self.__greek_word_betacode] = tab_separated_string #we add each row created for a word form to the cache of analyses
        return tab_separated_string

    def __should_log_error(self, betacode_word):
        # don't log words starting with a capital word to errors, or numerals
        return not (betacode_word.startswith('*') or any(c.isdigit() for c in betacode_word))


class VerticalObject: #a vertical object is a sentence, section, paragraph or header
    def doAnalysis(self):
        pass

#dealing with the metadata (author, title)
class VerticalHeader(VerticalObject):
    def __init__(self):
        self.__title = None
        self.__author = None

    def setTitle(self, title):
        if self.__title is None:
            self.__title = title

    def setAuthor(self, author):
        if self.__author is None:
            self.__author = author

    def setFilename(self, filename):
        head, tail = os.path.split(filename)
        self.__filename = tail

    def doAnalysis(self):
        print(f"<doc title=\"{self.__title}\" author=\"{self.__author}\">")


class VerticalSection(VerticalObject):#sections contain sentences, position info (e.g. section number, paragraph number, chapter number, book number)
    def __init__(self, positionInfo):
        self.__positionInfo = PositionInfo()
        self.__positionInfo.copy(positionInfo)
        self.__sentences = []

    def pushSentence(self, sentence):
        self.__sentences.append(sentence)

    def doAnalysis(self):
        positionInfo = self.__positionInfo.render()
        print(f"<p {positionInfo}>") #the tag starts the section and specifies all the higher-level position info 
        for sentence in self.__sentences:
            sentence.doAnalysis()
        print("</p>") #the tag closes a section 


class VerticalSentence(VerticalObject): #dealing with sentences 
    def __init__(self):
        self.__words = []

    def pushWord(self, word):
        self.__words.append(word)

    def doAnalysis(self):
        print("<s>")
        for word in self.__words:
            analysis = PerseusAnalysis(word)
            print(analysis.get_tab_separated_vertical_format()) #output the row of analyses we created for each word form into the vertical table 
        print("</s>")

class PositionInfo: #defines the positional info 
    def __init__(self):
        self.book = None          # div1 type="Book"
        self.speech = None        # div1 type="speech"

        self.section = None       # milestone unit="section"
        self.line = None          # milestone unit="line" or unit="Line"
        self.part = None          # milestone unit="part"
        self.chapter = None       # milestone unit="chapter"

    def setDiv1(self, type, n):
        if type == "Book":
            self.__reset()
            self.book = n
            return

        if type == "speech":
            self.__reset()
            self.speech = n
            return

        raise Exception("unknown div1 type: " + type)

    def setMilestone(self, unit, n):
        if unit == "section":
            self.section = n
            return

        if unit == "line" or unit == "Line":
            self.line = n
            return

        if unit == "part":
            self.part = n
            return

        if unit == "chapter":
            self.chapter = n
            return

        if unit == "para":
            # ignore
            return

        raise Exception("unknown milestone unit: " + unit)

    def copy(self, other): #whenever we start a new paragraph or section, we copy all the higher level positional information
        self.book = other.book
        self.speech = other.speech

        self.section = other.section
        self.line = other.line
        self.part = other.part
        self.chapter = other.chapter

    def render(self): #defines what has to be put in the vertical table so that Sketchengine can work out where we are in the document 
        metadata = ""

        if self.book is not None:
            metadata += f"book=\"{self.book}\""

        if self.speech is not None:
            if metadata != "":
                metadata += " "
            metadata += f"speech=\"{self.speech}\""

        if self.section is not None:
            if metadata != "":
                metadata += " "
            metadata += f"section=\"{self.section}\""

        if self.line is not None:
            if metadata != "":
                metadata += " "
            metadata += f"line=\"{self.line}\""

        if self.part is not None:
            if metadata != "":
                metadata += " "
            metadata += f"part=\"{self.part}\""

        if self.chapter is not None:
            if metadata != "":
                metadata += " "
            metadata += f"chapter=\"{self.chapter}\""

        return metadata


    def __reset(self): #when we start a new speech or book, we do not copy over the lower level positional information from the previous section 
        self.book = None
        self.speech = None

        self.section = None
        self.line = None
        self.part = None
        self.chapter = None

#goes through the xml files of the corpus with the code written above
class Tagger:
    def __init__(self, xml_file_path):
        self.__headerTagsToIgnore = [
            "biblStruct",     # repeats title and author
            "encodingDesc",
            "extent",
            "funder",
            "sponsor",
            "principal",
            "profileDesc",
            "publicationStmt",
            "respStmt",
            "revisionDesc",
            "sourceDesc",
        ]
        self.__knownHeaderTags = [
            "author",
            "fileDesc",       # wraps metadata, e.g. title and author
            "title",
            "titleStmt",
        ]
        self.__tagsToIgnore = [ #tags in the text body to ignore (currently none)
        ]
        self.__knownTags = [
            "add",             # appears before note
            "body",            # wraps main body content
            "del",             # appears before note
            "div1",            # wraps speeches
            "gap",
            "head",
            "milestone",
            "note",
            "p",
            "q",
            "quote",
            "TEI.2",           # wraps doc
            "teiHeader",       # wraps header
            "text",            # wraps body
            "title",
        ]

        self.__xml_file_path = xml_file_path
        self.__tree = ET.parse(xml_file_path) #reads the xml file and turns it into something Python can understand 
        self.__verticalObjects = []
        self.__header = VerticalHeader()
        self.__currentSection = None
        self.__currentSentence = None
        self.__forceNewSectionStartOnNextTag = False
        self.__positionInfo = PositionInfo()

        self.__header.setFilename(xml_file_path)

    def tag(self): #goes through the xml file and outputs a row containing the lemma and tags for each word form found 
        self.traverseXml(self.__tree.getroot())

        if self.__currentSentence is not None:
            self.__finishCurrentSentence()

        if self.__currentSection is not None:
            self.__finishCurrentSection()

    def traverseXml(self, element):
        traverseChildren = True #this helps us not to consider the content of in-text notes (in English, German, etc. e.g. on textual criticism)

        if element.tag in self.__tagsToIgnore:
            return

        if element.tag not in self.__knownTags:
            raise Exception("unknown tag: " + element.tag) #this stops the process if we encounter an unknown tag
        #these are all the different tags that we find in the xml file 
        if element.tag == "teiHeader":
            for elem in element.getchildren():
                self.traverseHeaderXml(elem)
            return

        if element.tag == "add":
            self.__addText(element.text)

        if element.tag == "del":
            self.__addText(element.text)

            if element.tail is not None and element.tail != "" and element.tail != "\n":
                self.__addText(element.tail)

        if element.tag == "div1":
            self.__positionInfo.setDiv1(element.attrib.get("type"), element.attrib.get("n"))

        if element.tag == "gap":
            if element.tail is not None and element.tail != "" and element.tail != "\n":
                self.__addText(element.tail)

        if element.tag == "head" or element.tag == "title":
            self.__addText(element.text, True, True) #True, True forces the tagger to start a new sentence and section when we encounter a head or title tag

        if element.tag == "milestone":
            self.__positionInfo.setMilestone(element.attrib.get("unit"), element.attrib.get("n"))

            if element.tail is not None and element.tail != "" and element.tail != "\n":
                self.__addText(element.tail, True, True)
            else:
                self.__forceNewSectionStartOnNextTag = True

        if element.tag == "note":
            traverseChildren = False

            if element.tail is not None and element.tail != "" and element.tail != "\n":
                self.__addText(element.tail)

        if element.tag == "q": #is this a footnote?????
            self.__addText(element.text)

            if element.tail is not None and element.tail != "" and element.tail != "\n":
                self.__addText(element.tail)

        if traverseChildren: 
            for elem in element.getchildren():
                self.traverseXml(elem)

    def traverseHeaderXml(self, element):
        if element.tag in self.__headerTagsToIgnore:
            return

        if element.tag not in self.__knownHeaderTags:
            raise Exception("unknown header tag: " + element.tag)

        if element.tag == "title":
            self.__header.setTitle(element.text)

        if element.tag == "author":
            self.__header.setAuthor(element.text)

        for elem in element.getchildren():
            self.traverseHeaderXml(elem)

    def doAnalysis(self): #creates the vertical file and outputs everything into the vertical file 
        self.__header.doAnalysis()
        for obj in self.__verticalObjects:
            obj.doAnalysis()
        print("</doc>") #ends the document 


    def __addText(self, unsplitText, forceSectionStart=False, forceSentenceStart=False, sectionMetadata=None):
        if self.__forceNewSectionStartOnNextTag:
            forceSectionStart = True
        self.__forceNewSectionStartOnNextTag = False

        if (forceSectionStart or forceSentenceStart) and self.__currentSentence is not None:
            self.__finishCurrentSentence()

        if forceSectionStart and self.__currentSection is not None:
            self.__finishCurrentSection()

        if self.__currentSection is None:
            self.__startNewSection()

        if self.__currentSentence is None:
            self.__startNewSentence()

        if unsplitText is None:
            return

        # TODO could add glue where the apostrophe is in the middle of the word
        unsplitText = unsplitText.replace("'", " ")#removes all the apostrophes from the text 

        for word in self.__splitWords(unsplitText):
            endOfSentence = False

            if self.__currentSentence is None:
                self.__startNewSentence()

            # strip word forms of punctuation (for the Perseus lookup & we do not output punctuation into the vertical file but use the defined sentences boundary
            # markers, etc. because Sketchengine can understand these 
            if "." in word:
                word = word.replace(".", "")
                endOfSentence = True
            translation_table = dict.fromkeys(map(ord, '（）† （）()†“”‘’&·—ʹ.,:;_#-"“ʼ‘“”'), None) #get rid of punctuation
            word = word.translate(translation_table)

            if len(word) > 0:
                self.__currentSentence.pushWord(word)

            if endOfSentence:
                self.__finishCurrentSentence() #if the word had a full stop, finish the current sentence 


    def __splitWords(self, text): #split words by means of space characters 
        return text.split()

    def __startNewSection(self):
        self.__currentSection = VerticalSection(self.__positionInfo)

    def __finishCurrentSection(self):
        self.__verticalObjects.append(self.__currentSection)
        self.__currentSection = None

    def __startNewSentence(self):
        self.__currentSentence = VerticalSentence()

    def __finishCurrentSentence(self):
        self.__currentSection.pushSentence(self.__currentSentence)
        self.__currentSentence = None



if __name__ == "__main__": #this is running all the code above when you start the program (this program has to be run on each document in the corpus separately, cat)
    xml_file_path = sys.argv[1]

    tagger = Tagger(xml_file_path)
    tagger.tag()
    tagger.doAnalysis()


"""
    try:
        # remove brackets
        translation_table = dict.fromkeys(map(ord, '（）† '), None)
        stripped_word = word.translate(translation_table)

        # deal with bracket at start of work
        if "（" in word:
            print("（")

        analysis = PerseusAnalysis(stripped_word)
        print(analysis.get_tab_separated_vertical_format())

        if "）" in word:
            print("）")

    except Exception:
        unicode_greek_word = betacode.conv.beta_to_uni(word)
        print(unicode_greek_word)
        with open('errors.txt', 'a') as f:
            f.write(f"{word}    {unicode_greek_word}    unknown error\n")
        sys.stderr.write(f"Cannot find lemma for word {word}\n")
"""
