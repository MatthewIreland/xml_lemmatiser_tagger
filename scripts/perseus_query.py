import betacode.conv
import urllib.request
import re
import sys
import time


class PerseusAnalysis:
    def __init__(self, greek_word):
        self.__greek_word_betacode = greek_word
        self.__get_perseus_analysis(greek_word)

    def __get_perseus_analysis(self, greek_word):
        greek_word_encoded = urllib.parse.quote_plus(greek_word)
        unicode_greek_word = betacode.conv.beta_to_uni(word)

        try:
            file = urllib.request.urlopen(f"https://www.perseus.tufts.edu/hopper/morph?l={greek_word_encoded}&la=greek")
            data = file.read().decode("utf=8")
            file.close()
        except Exception:
            try:
                sys.stderr.write(f"Error looking up {greek_word_encoded}. Retrying...\n")
                time.sleep(60)
                file = urllib.request.urlopen(f"https://www.perseus.tufts.edu/hopper/morph?l={greek_word_encoded}&la=greek")
                data = file.read().decode("utf=8")
                file.close()
            except Exception as e:
                sys.stderr.write(f"Retry failed.\n")
                raise e


        matches = re.findall('<td class="greek">(.*)</td>.*\n.*<td>(.*)</td>', data)

        lemmata = []
        pos_tags = []

        num_pos_tags = 0
        for match in matches:
            pos_tags.append(match[1].split(" ")[0])
            num_pos_tags += 1
            with open('all_pos_tags.txt', 'a') as f:
                for tag in match[1].split(" "):
                    f.write(f"{unicode_greek_word}     {tag}\n")

        if num_pos_tags == 0:
            with open('errors.txt', 'a') as f:
                f.write(f"{word}    {unicode_greek_word}    can't find pos tags\n")


        matches = re.findall('<h4 class="greek">(.*)</h4>', data)

        num_lemmata = 0
        for match in matches:
            if match != "ἔχω2":
                lemmata.append(match)
                num_lemmata += 1

        if num_lemmata == 0:
            with open('errors.txt', 'a') as f:
                f.write(f"{word}    {unicode_greek_word}    can't find lemma\n")

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
        # remove brackets
        translation_table = dict.fromkeys(map(ord, '（）†'), None)
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
