//
//  Localization.swift
//  XInterview2
//
//  Simple localization helpers
//

import Foundation

enum L10n {
    private static func currentLanguage() -> Language {
        let raw = UserDefaults.standard.string(forKey: UserDefaultsKeys.selectedInterfaceLanguage) ?? Language.english.rawValue
        return Language(rawValue: raw) ?? .english
    }
    
    private static func bundle(for language: Language) -> Bundle {
        guard let path = Bundle.main.path(forResource: language.rawValue, ofType: "lproj"),
              let bundle = Bundle(path: path) else {
            return .main
        }
        return bundle
    }
    
    static func text(_ key: String) -> String {
        let language = currentLanguage()
        let bundle = bundle(for: language)
        return bundle.localizedString(forKey: key, value: nil, table: nil)
    }
    
    static func format(_ key: String, _ arguments: CVarArg...) -> String {
        let language = currentLanguage()
        let bundle = bundle(for: language)
        let format = bundle.localizedString(forKey: key, value: nil, table: nil)
        return String(format: format, locale: language.locale, arguments: arguments)
    }
}
