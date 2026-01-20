//
//  ContentView.swift
//  XInterview2
//
//  Main view for the app - redirects to MainView
//

import SwiftUI

struct ContentView: View {
    @AppStorage(UserDefaultsKeys.selectedInterfaceLanguage) private var interfaceLanguageRaw = Language.english.rawValue
    
    var body: some View {
        MainView()
            .environment(\.locale, interfaceLanguage.locale)
    }
    
    private var interfaceLanguage: Language {
        Language(rawValue: interfaceLanguageRaw) ?? .english
    }
}

#Preview {
    ContentView()
}
