//
//  AdvancedSearch.swift
//  Cyte
//
//  Created by Shaun Narayan on 9/04/23.
//

import Foundation
import SwiftUI

struct AdvancedSearchView: View {
    @Environment(\.managedObjectContext) private var viewContext
    @EnvironmentObject var bundleCache: BundleCache
    @EnvironmentObject var episodeModel: EpisodeModel
    
    @State private var isPresentingConfirm: Bool = false
    
    @State private var isHovering: Bool = false
    @State private var isHoveringFilter: Bool = false
    
    let documentsColumnLayout = [
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading),
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading),
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading),
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading),
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading),
        GridItem(.fixed(190), spacing: 10, alignment: .topLeading)
    ]        
    
    var body: some View {
        VStack {
            HStack(alignment: .center) {
                DatePicker(
                    "",
                    selection: $episodeModel.startDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: episodeModel.startDate, perform: { value in
                    episodeModel.refreshData()
                })
                .accessibilityLabel("Set the earliest date/time for recording results")
                .frame(width: 200, alignment: .leading)
                DatePicker(
                    " - ",
                    selection: $episodeModel.endDate,
                    displayedComponents: [.date, .hourAndMinute]
                )
                .onChange(of: episodeModel.endDate, perform: { value in
                    episodeModel.refreshData()
                })
                .accessibilityLabel("Set the latest date/time for recording results")
                .frame(width: 200, alignment: .leading)
                Spacer()
                Text("\(secondsToReadable(seconds: episodeModel.episodesLengthSum)) displayed")
                Button(action: {
                    isPresentingConfirm = true
                }) {
                    Image(systemName: "folder.badge.minus")
                }
                .buttonStyle(.plain)
#if os(macOS)
                .onHover(perform: { hovering in
                    self.isHovering = hovering
                    if hovering {
                        NSCursor.pointingHand.set()
                    } else {
                        NSCursor.arrow.set()
                    }
                })
#endif
                .confirmationDialog("This action cannot be undone. Are you sure?",
                 isPresented: $isPresentingConfirm) {
                    Button("Delete all results", role: .destructive) {
                        for episode in episodeModel.episodes {
                             Memory.shared.delete(delete_episode: episode)
                         }
                         episodeModel.refreshData()
                    }
                }
            }
#if os(macOS)
            ScrollView {
                LazyVGrid(columns: documentsColumnLayout, spacing: 20) {
                    ForEach(Set(episodeModel.episodes.map { $0.bundle ?? Bundle.main.bundleIdentifier! }).sorted(by: <), id: \.self) { bundle in
                        HStack {
                            Image(nsImage: bundleCache.getIcon(bundleID: bundle))
                                .frame(width: 32, height: 32)
                            Text(getApplicationNameFromBundleID(bundleID: bundle) ?? "")
                        }
                        .contentShape(Rectangle())
                        .onHover(perform: { hovering in
                            self.isHoveringFilter = hovering
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        })
                        .onTapGesture { gesture in
                            if episodeModel.highlightedBundle.count == 0 {
                                withAnimation(.easeOut(duration: 0.3)) {
                                    episodeModel.highlightedBundle = bundle
                                }
                            } else {
                                episodeModel.highlightedBundle = ""
                            }
                            self.episodeModel.refreshData()
                        }
                    }
                }
            }
            .frame(height: 50)
            HStack {
                LazyVGrid(columns: documentsColumnLayout, spacing: 20) {
                    ForEach(episodeModel.documentsForBundle) { doc in
                        HStack {
                            Image(nsImage: NSWorkspace.shared.icon(forFile: String(doc.path!.absoluteString.starts(with: "http") ? doc.path!.absoluteString : String(doc.path!.absoluteString.dropFirst(7)))))
                            Text(doc.path!.lastPathComponent)
                                .foregroundColor(.black)
                        }
                        .onHover(perform: { hovering in
                            self.isHoveringFilter = hovering
                            if hovering {
                                NSCursor.pointingHand.set()
                            } else {
                                NSCursor.arrow.set()
                            }
                        })
                        .onTapGesture { gesture in
                            // @todo should maybe open with currently highlighted bundle?
                            NSWorkspace.shared.open(doc.path!)
                        }
                    }
                }
            }
#endif
        }
        .contentShape(Rectangle())
        .padding(EdgeInsets(top: 10, leading: 10, bottom: 10, trailing: 10))
    }
}
