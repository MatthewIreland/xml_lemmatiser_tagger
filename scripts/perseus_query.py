import betacode.conv
import urllib
import re
import sys
import xmltodict


class PerseusAnalysis:
    def __init__(self, greek_word):
        self.__greek_word_betacode = greek_word
        self.__get_perseus_analysis(greek_word)

    def __get_perseus_analysis(self, greek_word):
        greek_word_encoded = urllib.parse.quote_plus(greek_word)

        file = urllib.request.urlopen(f"https://www.perseus.tufts.edu/hopper/morph?l={greek_word_encoded}&la=greek")
        data = file.read().decode("utf=8")
        file.close()

        matches = re.findall('<td class="greek">(.*)</td>.*\n.*<td>(.*)</td>', data)

        lemmata = []
        pos_tags = []

        for match in matches:
            pos_tags.append(match[1].split(" ")[0])

        matches = re.findall('<h4 class="greek">(.*)</h4>', data)

        for match in matches:
            lemmata.append(match)

        self.__lemmata = list(set(lemmata))
        self.__pos_tags = list(set(pos_tags))


    def get_pos_tags(self):
        return self.__pos_tags

    def get_lemmata(self):
        return self.__lemmata


    def get_tab_separated_vertical_format(self):
        greek_word = betacode.conv.beta_to_uni(self.__greek_word_betacode)
        lemmata = ";".join(self.get_lemmata())
        pos_tags = ";".join(self.get_pos_tags())

        tab_separated_string = "\t".join([greek_word, pos_tags, lemmata])

        return tab_separated_string


if __name__ == "__main__":
    word = sys.argv[1]

    try:
        analysis = PerseusAnalysis(word)
        print(analysis.get_tab_separated_vertical_format())
    except Exception:
        unicode_greek_word = betacode.conv.beta_to_uni(word)
        print(unicode_greek_word)
        with open('errors.txt', 'w') as f:
            f.write(f"{word}    {unicode_greek_word}\n")
        sys.stderr.write(f"Cannot find lemma for word {word}\n")
