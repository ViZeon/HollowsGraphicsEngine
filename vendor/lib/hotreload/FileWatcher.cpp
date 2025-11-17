#include "FileWatcher.hpp"
#include <utility>   // std::move

FileWatcher::FileWatcher(const std::string& path, Callback cb)
    : m_path(path)
    , m_callback(std::move(cb))
    , m_watcher(new efsw::FileWatcher)
{
    m_watchId = m_watcher->addWatch(m_path, this, /* recursive */ true);
    m_watcher->watch();
}

FileWatcher::~FileWatcher()
{
    if (m_watcher) {
        m_watcher->removeWatch(m_watchId);
        delete m_watcher;
    }
}

void FileWatcher::handleFileAction(efsw::WatchID /*watchid*/,
                                   const std::string& dir,
                                   const std::string& filename,
                                   efsw::Action action,
                                   std::string /*oldFilename*/)
{
    // We only care about new or modified files
    if (action == efsw::Actions::Add || action == efsw::Actions::Modified) {
        const std::string fullPath = dir + filename;
        if (m_callback) {
            m_callback(fullPath);
        }
    }
}